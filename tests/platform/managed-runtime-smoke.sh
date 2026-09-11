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
readonly MANAGED_PYTHON_SYSTEM_BINARY="${LIBRENMS_MANAGED_PYTHON_SYSTEM_BINARY:-}"
readonly PYTHON_315_PREVIEW_ENABLED="${LIBRENMS_PYTHON_315_PREVIEW_ENABLED:-false}"
TEST_DIR="$(mktemp -d "${ROOT_DIR}/.managed-runtime-smoke.XXXXXX")"
readonly TEST_DIR
readonly RESOURCE_TOKEN="$(basename "${TEST_DIR}")"
readonly RESOURCE_ID="$(printf '%s' "${RESOURCE_TOKEN}" | tr -cd 'a-zA-Z0-9' | tail -c 8)"
readonly RESOURCE_SUFFIX="${CASE_NAME//[^a-zA-Z0-9]/-}-${RESOURCE_ID}"
readonly TARGET_CONTAINER="librenms-platform-target-${RESOURCE_SUFFIX}"
readonly TARGET_NETWORK="librenms-platform-network-${RESOURCE_SUFFIX}"
readonly TEST_PASSWORD="librenms-smoke-${RESOURCE_ID}"

docker_cmd() {
    MSYS_NO_PATHCONV=1 docker "$@"
}

docker_host_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s' "$1"
    fi
}

readonly ROOT_VOLUME="$(docker_host_path "${ROOT_DIR}"):/workspace:ro"
readonly TEST_VOLUME="$(docker_host_path "${TEST_DIR}"):/test:ro"

cleanup() {
    docker_cmd rm -f "${TARGET_CONTAINER}" >/dev/null 2>&1 || true
    docker_cmd network rm "${TARGET_NETWORK}" >/dev/null 2>&1 || true
    rm -rf "${TEST_DIR}"
}
trap cleanup EXIT

docker_cmd network create "${TARGET_NETWORK}" >/dev/null
docker_cmd run --detach --name "${TARGET_CONTAINER}" \
    --hostname "${TARGET_CONTAINER}" \
    --network "${TARGET_NETWORK}" \
    "${TARGET_IMAGE}" sleep infinity >/dev/null

case "${TARGET_IMAGE}" in
    ubuntu:*)
        docker_cmd exec --env DEBIAN_FRONTEND=noninteractive "${TARGET_CONTAINER}" \
            bash -lc 'apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 update -q && apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 install -y --no-install-recommends ca-certificates openssh-server'
        ;;
    python:*)
        docker_cmd exec --env DEBIAN_FRONTEND=noninteractive "${TARGET_CONTAINER}" \
            bash -lc 'apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 update -q && apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 install -y --no-install-recommends ca-certificates openssh-server'
        ;;
    rockylinux/*|almalinux:*|rhel:*|registry.access.redhat.com/*|registry.redhat.io/*)
        docker_cmd exec "${TARGET_CONTAINER}" \
            bash -lc 'dnf --setopt=retries=10 --setopt=timeout=30 -y --setopt=install_weak_deps=False install ca-certificates openssh-server'
        ;;
    *)
        printf 'Unsupported managed-runtime smoke image: %s\n' "${TARGET_IMAGE}" >&2
        exit 2
        ;;
esac

ssh-keygen -q -t ed25519 -N '' -f "${TEST_DIR}/id_ed25519"
docker_cmd exec "${TARGET_CONTAINER}" bash -lc \
    'install -d -m 0700 /root/.ssh /run/sshd && ssh-keygen -A'
docker_cmd cp "$(docker_host_path "${TEST_DIR}/id_ed25519.pub")" \
    "${TARGET_CONTAINER}:/root/.ssh/authorized_keys" >/dev/null
docker_cmd exec "${TARGET_CONTAINER}" chmod 0600 /root/.ssh/authorized_keys
docker_cmd exec -e "LIBRENMS_SMOKE_PASSWORD=${TEST_PASSWORD}" \
    "${TARGET_CONTAINER}" bash -lc \
    'printf "root:%s\\n" "${LIBRENMS_SMOKE_PASSWORD}" | chpasswd'
docker_cmd exec "${TARGET_CONTAINER}" bash -lc \
    'install -d -m 0755 /etc/ssh/sshd_config.d && printf "%s\\n" \
        "PermitRootLogin yes" \
        "PubkeyAuthentication yes" \
        "PasswordAuthentication yes" \
        "AuthorizedKeysFile /root/.ssh/authorized_keys" \
        > /etc/ssh/sshd_config.d/99-librenms-managed-runtime-smoke.conf'
docker_cmd exec --detach "${TARGET_CONTAINER}" /usr/sbin/sshd -D -e \
    -o PermitRootLogin=yes \
    -o PubkeyAuthentication=yes \
    -o PasswordAuthentication=yes \
    -o AuthorizedKeysFile=/root/.ssh/authorized_keys

for _ in $(seq 1 30); do
    if docker_cmd exec "${TARGET_CONTAINER}" \
        bash -lc 'exec 3<>/dev/tcp/127.0.0.1/22' 2>/dev/null; then
        break
    fi
    sleep 1
done

if ! docker_cmd exec "${TARGET_CONTAINER}" \
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
          ansible_password: ${TEST_PASSWORD}
          ansible_ssh_private_key_file: /test/id_ed25519
          ansible_python_interpreter: /opt/librenms-ha-ansible/python/bin/python
          ansible_ssh_common_args: >-
            -o IdentitiesOnly=yes -o PreferredAuthentications=password,publickey
            -o PubkeyAuthentication=yes -o KbdInteractiveAuthentication=no
            -o StrictHostKeyChecking=no
            -o UserKnownHostsFile=/dev/null
EOF

ansible_extra_args=()
if [ -n "${MANAGED_PYTHON_SYSTEM_BINARY}" ]; then
    ansible_extra_args+=(
        -e
        "librenms_managed_python_system_binary=${MANAGED_PYTHON_SYSTEM_BINARY}"
    )
fi
if [ "${EXPECTED_PYTHON}" = "3.15" ]; then
    case "${PYTHON_315_PREVIEW_ENABLED}" in
        true|false)
            ;;
        *)
            printf 'LIBRENMS_PYTHON_315_PREVIEW_ENABLED must be true or false.\n' >&2
            exit 2
            ;;
    esac
    if [ "${PYTHON_315_PREVIEW_ENABLED}" = "true" ]; then
        ansible_extra_args+=(
            -e
            librenms_python_315_preview_enabled=true
        )
    fi
fi

docker_cmd run --rm \
    --network "${TARGET_NETWORK}" \
    --volume "${ROOT_VOLUME}" \
    --volume "${TEST_VOLUME}" \
    --workdir /workspace \
    --env ANSIBLE_CONFIG=/workspace/ansible.cfg \
    --env ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections \
    --env ANSIBLE_HOST_KEY_CHECKING=False \
    "${CONTROLLER_IMAGE}" \
    ansible-playbook \
      -i /test/hosts.yml \
      /workspace/tests/platform/managed-runtime-smoke.yml \
      -e "librenms_platform_expected_python=${EXPECTED_PYTHON}" \
      "${ansible_extra_args[@]}"

printf 'Managed-runtime smoke test passed for %s with Python %s.\n' \
    "${TARGET_IMAGE}" "${EXPECTED_PYTHON}"
