#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
requirements_file="${LIBRENMS_ANSIBLE_REQUIREMENTS_FILE:-${repo_root}/requirements.yml}"
collections_path="${LIBRENMS_ANSIBLE_COLLECTIONS_PATH:-${repo_root}/.ansible/collections}"
collection_state_checker="${repo_root}/scripts/ansible-collection-state.py"
galaxy_bin="${ANSIBLE_GALAXY_BIN:-ansible-galaxy}"
playbook_bin="${ANSIBLE_PLAYBOOK_BIN:-ansible-playbook}"
python_bin="${PYTHON_BIN:-python3}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ -f "${requirements_file}" ] || fail "Ansible collection requirements not found: ${requirements_file}"
[ -f "${collection_state_checker}" ] || fail "Collection state checker not found: ${collection_state_checker}"
command -v "${galaxy_bin}" >/dev/null 2>&1 || fail "Required command not found: ${galaxy_bin}"
command -v "${playbook_bin}" >/dev/null 2>&1 || fail "Required command not found: ${playbook_bin}"
command -v "${python_bin}" >/dev/null 2>&1 || fail "Required command not found: ${python_bin}"

export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-${repo_root}/ansible.cfg}"
if [ -n "${ANSIBLE_COLLECTIONS_PATH:-}" ]; then
    export ANSIBLE_COLLECTIONS_PATH="${collections_path}:${ANSIBLE_COLLECTIONS_PATH}"
else
    export ANSIBLE_COLLECTIONS_PATH="${collections_path}"
fi

cd "${repo_root}"
mkdir -p "${collections_path}"

printf 'Synchronizing pinned Ansible collections from %s\n' "${requirements_file}"
collection_install_args=(
    collection install
    -r "${requirements_file}"
    -p "${collections_path}"
)
collection_state_output=""
collection_state_rc=0
collection_state_output="$(
    "${python_bin}" "${collection_state_checker}" \
        --requirements "${requirements_file}" \
        --collections-path "${collections_path}" 2>&1
)" || collection_state_rc=$?

case "${collection_state_rc}" in
    0)
        ;;
    10)
        printf '%s\n' "${collection_state_output}"
        printf 'Refreshing mismatched project-local collections once.\n'
        collection_install_args+=(--force)
        ;;
    *)
        fail "Unable to inspect installed Ansible collections: ${collection_state_output}"
        ;;
esac

if [ "${collection_state_rc}" -eq 10 ]; then
    ANSIBLE_COLLECTIONS_ON_ANSIBLE_VERSION_MISMATCH=ignore \
        "${galaxy_bin}" "${collection_install_args[@]}" || \
        fail "Unable to install the pinned Ansible collections; no playbook was started."
elif ! "${galaxy_bin}" "${collection_install_args[@]}"; then
    fail "Unable to install the pinned Ansible collections; no playbook was started."
fi

collection_state_output=""
collection_state_rc=0
collection_state_output="$(
    "${python_bin}" "${collection_state_checker}" \
        --requirements "${requirements_file}" \
        --collections-path "${collections_path}" \
        --require-installed 2>&1
)" || collection_state_rc=$?

if [ "${collection_state_rc}" -ne 0 ]; then
    fail "Pinned Ansible collection synchronization did not converge: ${collection_state_output}"
fi

exec "${playbook_bin}" "$@"
