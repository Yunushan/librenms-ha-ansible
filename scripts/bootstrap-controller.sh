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

ensure_controller_pip() {
    local controller_python="${venv_path}/bin/python"

    if "${controller_python}" -m pip --version >/dev/null 2>&1; then
        return 0
    fi

    printf 'Controller virtual environment is missing pip; attempting repair with ensurepip.\n'
    if "${controller_python}" -m ensurepip --upgrade \
        && "${controller_python}" -m pip --version >/dev/null 2>&1; then
        return 0
    fi

    fail "Controller virtual environment ${venv_path} is incomplete and pip repair failed. Install the Python ${controller_python_version} venv package (Ubuntu/Debian: apt install python${controller_python_version}-venv), then rerun 'make controller-bootstrap'."
}

command -v "${bootstrap_python}" >/dev/null 2>&1 || \
    fail "Python command not found: ${bootstrap_python}"
[ -f "${requirements_file}" ] || \
    fail "Pinned controller requirements not found: ${requirements_file}"

controller_python_version="$(
    "${bootstrap_python}" -c \
        'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
)"
python_315_preview_enabled="${LIBRENMS_PYTHON_315_PREVIEW_ENABLED:-false}"
if ! "${bootstrap_python}" -c \
    'import sys; raise SystemExit(not ((3, 12) <= sys.version_info[:2] <= (3, 15)))'; then
    fail "Python 3.12 through 3.15 is required to bootstrap the controller; found ${controller_python_version}."
fi

controller_ansible_core_version="$(
    sed -n -E 's/^ansible-core==([0-9]+\.[0-9]+\.[0-9]+([.]dev[0-9]+|[.]?(a|b|rc)[0-9]+)?).*/\1/p' "${requirements_file}" \
        | sed -n '1p'
)"
[ -n "${controller_ansible_core_version}" ] || \
    fail "Pinned controller requirements must contain an exact ansible-core version."

controller_core_major="${controller_ansible_core_version%%.*}"
controller_core_remainder="${controller_ansible_core_version#*.}"
controller_core_minor="${controller_core_remainder%%.*}"
case "${controller_core_major}:${controller_core_minor}" in
    *[!0-9:]*|'')
        fail "Invalid pinned ansible-core version: ${controller_ansible_core_version}"
        ;;
esac

if [ "${controller_python_version}" = "3.15" ] \
    && { [ "${controller_core_major}" -lt 2 ] \
        || { [ "${controller_core_major}" -eq 2 ] \
            && [ "${controller_core_minor}" -lt 22 ]; }; }; then
    fail "Python 3.15 requires ansible-core 2.22.0 or newer; the pinned controller has ${controller_ansible_core_version}."
fi

if [ "${controller_python_version}" = "3.15" ]; then
    case "${python_315_preview_enabled}" in
        true|false)
            ;;
        *)
            fail "LIBRENMS_PYTHON_315_PREVIEW_ENABLED must be true or false."
            ;;
    esac

    if printf '%s\n' "${controller_ansible_core_version}" \
        | grep -Eq '([.]dev[0-9]+|[.]?(a|b|rc)[0-9]+)$'; then
        if [ "${python_315_preview_enabled}" != "true" ] \
            || ! printf '%s\n' "${controller_ansible_core_version}" \
                | grep -Eq '^2[.]22[.][0-9]+([.]dev[0-9]+|[.]?(a|b|rc)[0-9]+)$'; then
            fail "Python 3.15 requires stable ansible-core 2.22.0 or newer; pre-release 2.22 builds require LIBRENMS_PYTHON_315_PREVIEW_ENABLED=true (found ${controller_ansible_core_version})."
        fi
    fi
fi

if [ "${controller_python_version}" = "3.12" ] \
    && { [ "${controller_core_major}" -gt 2 ] \
        || { [ "${controller_core_major}" -eq 2 ] \
            && [ "${controller_core_minor}" -ge 22 ]; }; }; then
    fail "ansible-core ${controller_ansible_core_version} requires controller Python 3.13 through 3.15; found ${controller_python_version}."
fi

if [ ! -x "${venv_path}/bin/python" ]; then
    mkdir -p "$(dirname "${venv_path}")"
    "${bootstrap_python}" -m venv "${venv_path}" || \
        fail "Unable to create ${venv_path}; install the Python venv package and retry."
fi

controller_venv_python_version="$(
    "${venv_path}/bin/python" -c \
        'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
)"
[ -n "${controller_venv_python_version}" ] || \
    fail "Unable to determine the controller virtual environment Python version: ${venv_path}/bin/python"
if [ "${controller_venv_python_version}" != "${controller_python_version}" ]; then
    fail "Controller virtual environment ${venv_path} uses Python ${controller_venv_python_version}, but the selected bootstrap interpreter is Python ${controller_python_version}. Recreate the controller virtual environment before continuing."
fi

ensure_controller_pip

"${venv_path}/bin/python" -m pip install \
    --disable-pip-version-check \
    --require-hashes \
    --requirement "${requirements_file}"
"${venv_path}/bin/python" -m pip check

printf 'Pinned Ansible controller is ready at %s\n' "${venv_path}"
"${venv_path}/bin/ansible-playbook" --version | sed -n '1p'
