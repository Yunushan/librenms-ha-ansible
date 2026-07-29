#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
requirements_file="${LIBRENMS_ANSIBLE_REQUIREMENTS_FILE:-${repo_root}/requirements.yml}"
collections_path="${LIBRENMS_ANSIBLE_COLLECTIONS_PATH:-${repo_root}/.ansible/collections}"
galaxy_bin="${ANSIBLE_GALAXY_BIN:-ansible-galaxy}"
playbook_bin="${ANSIBLE_PLAYBOOK_BIN:-ansible-playbook}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ -f "${requirements_file}" ] || fail "Ansible collection requirements not found: ${requirements_file}"
command -v "${galaxy_bin}" >/dev/null 2>&1 || fail "Required command not found: ${galaxy_bin}"
command -v "${playbook_bin}" >/dev/null 2>&1 || fail "Required command not found: ${playbook_bin}"

export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-${repo_root}/ansible.cfg}"
if [ -n "${ANSIBLE_COLLECTIONS_PATH:-}" ]; then
    export ANSIBLE_COLLECTIONS_PATH="${collections_path}:${ANSIBLE_COLLECTIONS_PATH}"
else
    export ANSIBLE_COLLECTIONS_PATH="${collections_path}"
fi

cd "${repo_root}"
mkdir -p "${collections_path}"

printf 'Synchronizing pinned Ansible collections from %s\n' "${requirements_file}"
if ! "${galaxy_bin}" collection install \
    -r "${requirements_file}" \
    -p "${collections_path}"; then
    fail "Unable to install the pinned Ansible collections; no playbook was started."
fi

exec "${playbook_bin}" "$@"
