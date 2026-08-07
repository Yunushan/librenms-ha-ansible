#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 3 ]; then
    printf 'Usage: %s IMAGE EXPECTED_PYTHON CASE_NAME\n' "$0" >&2
    exit 2
fi

readonly ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
readonly TARGET_IMAGE="$1"
readonly EXPECTED_PYTHON="$2"
readonly CASE_NAME="$3"
readonly CONTROLLER_IMAGE="${LIBRENMS_CONTROLLER_IMAGE:-librenms-ha-ansible-controller:local}"
TEST_DIR="$(mktemp -d)"
readonly TEST_DIR
readonly RESOURCE_TOKEN="$(basename "${TEST_DIR}")"
readonly RESOURCE_SUFFIX="${CASE_NAME//[^a-zA-Z0-9]/-}-${RESOURCE_TOKEN}"
readonly TARGET_CONTAINER="librenms-platform-target-${RESOURCE_SUFFIX}"
readonly TARGET_NETWORK="librenms-platform-network-${RESOURCE_SUFFIX}"

cleanup() {
    docker rm -f "${TARGET_CONTAINER}" >/dev/null 2>&1 || true
    docker network rm "${TARGET_NETWORK}" >/dev/null 2>&1 || true
    rm -rf "${TEST_DIR}"
}
trap cleanup EXIT

docker network create "${TARGET_NETWORK}" >/dev/null
docker run --detach --name "${TARGET_CONTAINER}" \
    --hostname "${TARGET_CONTAINER}" \
    --network "${TARGET_NETWORK}" \
    "${TARGET_IMAGE}" sleep infinity >/dev/null

case "${TARGET_IMAGE}" in
    ubuntu:*)
        docker exec --env DEBIAN_FRONTEND=noninteractive "${TARGET_CONTAINER}" \
            bash -lc 'apt-get update -q && apt-get install -y --no-install-recommends ca-certificates openssh-server'
        ;;
    rockylinux/*|almalinux:*)
        docker exec "${TARGET_CONTAINER}" \
            bash -lc 'dnf -y install ca-certificates openssh-server'
        ;;
    *)
        printf 'Unsupported managed-runtime smoke image: %s\n' "${TARGET_IMAGE}" >&2
        exit 2
        ;;
esac

ssh-keygen -q -t ed25519 -N '' -f "${TEST_DIR}/id_ed25519"
docker exec "${TARGET_CONTAINER}" bash -lc \
    'install -d -m 0700 /root/.ssh /run/sshd && ssh-keygen -A'
docker cp "${TEST_DIR}/id_ed25519.pub" \
    "${TARGET_CONTAINER}:/root/.ssh/authorized_keys" >/dev/null
docker exec "${TARGET_CONTAINER}" chmod 0600 /root/.ssh/authorized_keys
docker exec --detach "${TARGET_CONTAINER}" /usr/sbin/sshd -D -e

for _ in $(seq 1 30); do
    if docker exec "${TARGET_CONTAINER}" \
        bash -lc 'exec 3<>/dev/tcp/127.0.0.1/22' 2>/dev/null; then
        break
    fi
    sleep 1
done

if ! docker exec "${TARGET_CONTAINER}" \
    bash -lc 'exec 3<>/dev/tcp/127.0.0.1/22' 2>/dev/null; then
    printf 'SSH did not become ready in %s.\n' "${TARGET_CONTAINER}" >&2
    exit 1
fi

cat >"${TEST_DIR}/hosts.yml" <<EOF
---
all:
  children:
    librenms_nodes:
      hosts:
        platform-target:
          ansible_host: ${TARGET_CONTAINER}
          ansible_user: root
          ansible_ssh_private_key_file: /test/id_ed25519
          ansible_python_interpreter: /opt/librenms-ha-ansible/python/bin/python
          ansible_ssh_common_args: >-
            -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
EOF

docker run --rm \
    --network "${TARGET_NETWORK}" \
    --volume "${ROOT_DIR}:/workspace:ro" \
    --volume "${TEST_DIR}:/test:ro" \
    --workdir /workspace \
    --env ANSIBLE_CONFIG=/workspace/ansible.cfg \
    --env ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections \
    --env ANSIBLE_HOST_KEY_CHECKING=False \
    "${CONTROLLER_IMAGE}" \
    ansible-playbook \
      -i /test/hosts.yml \
      /workspace/tests/platform/managed-runtime-smoke.yml \
      -e "librenms_platform_expected_python=${EXPECTED_PYTHON}"

printf 'Managed-runtime smoke test passed for %s with Python %s.\n' \
    "${TARGET_IMAGE}" "${EXPECTED_PYTHON}"
