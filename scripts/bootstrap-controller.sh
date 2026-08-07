#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
venv_path="${LIBRENMS_ANSIBLE_CONTROLLER_VENV:-${repo_root}/.ansible/controller-venv}"
requirements_file="${LIBRENMS_ANSIBLE_CONTROLLER_REQUIREMENTS:-${repo_root}/requirements-ci.txt}"
bootstrap_python="${PYTHON_BIN:-python3}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

command -v "${bootstrap_python}" >/dev/null 2>&1 || \
    fail "Python command not found: ${bootstrap_python}"
[ -f "${requirements_file}" ] || \
    fail "Pinned controller requirements not found: ${requirements_file}"

controller_python_version="$(
    "${bootstrap_python}" -c \
        'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
)"
if ! "${bootstrap_python}" -c \
    'import sys; raise SystemExit(not ((3, 12) <= sys.version_info[:2] <= (3, 14)))'; then
    fail "Python 3.12 through 3.14 is required to bootstrap the controller; found ${controller_python_version}."
fi

if [ ! -x "${venv_path}/bin/python" ]; then
    mkdir -p "$(dirname "${venv_path}")"
    "${bootstrap_python}" -m venv "${venv_path}" || \
        fail "Unable to create ${venv_path}; install the Python venv package and retry."
fi

"${venv_path}/bin/python" -m pip install \
    --disable-pip-version-check \
    --require-hashes \
    --requirement "${requirements_file}"
"${venv_path}/bin/python" -m pip check

printf 'Pinned Ansible controller is ready at %s\n' "${venv_path}"
"${venv_path}/bin/ansible-playbook" --version | sed -n '1p'
