#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
launcher="${repo_root}/scripts/ansible-playbook.sh"
ansible_config="${repo_root}/ansible.cfg"
collection_requirements="${repo_root}/requirements.yml"
collection_state_checker="${repo_root}/scripts/ansible-collection-state.py"
controller_bootstrap="${repo_root}/scripts/bootstrap-controller.sh"
controller_requirements="${repo_root}/requirements-ci.txt"
python_bin="${PYTHON_BIN:-python3}"
selected_python_version="$("${python_bin}" -c \
    'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT

if [ ! -x "${controller_bootstrap}" ]; then
    echo "Controller bootstrap script must be executable." >&2
    exit 1
fi

write_manifest() {
    local root="$1"
    local namespace="$2"
    local collection="$3"
    local version="$4"
    local collection_dir="${root}/ansible_collections/${namespace}/${collection}"

    mkdir -p "${collection_dir}"
    printf '{"collection_info":{"version":"%s"}}\n' "${version}" \
        > "${collection_dir}/MANIFEST.json"
}

grep -Eq '^stdout_callback[[:space:]]*=[[:space:]]*ansible\.builtin\.default[[:space:]]*$' "${ansible_config}"
grep -Eq '^callback_result_format[[:space:]]*=[[:space:]]*yaml[[:space:]]*$' "${ansible_config}"

if grep -Eq '^stdout_callback[[:space:]]*=[[:space:]]*yaml[[:space:]]*$' "${ansible_config}"; then
    echo "The removed community.general.yaml callback must not be configured." >&2
    exit 1
fi

grep -A1 -F -- '- name: community.general' "${collection_requirements}" \
    | grep -Eq 'version:[[:space:]]*11\.4\.8[[:space:]]*$'
controller_core_version="$(
    sed -n -E 's/^ansible-core==([0-9]+\.[0-9]+\.[0-9]+([.]dev[0-9]+|[.]?(a|b|rc)[0-9]+)?).*/\1/p' \
        "${controller_requirements}" \
        | sed -n '1p'
)"
[ -n "${controller_core_version}" ]
grep -Fq "ansible-core==${controller_core_version}" "${controller_requirements}"
grep -Fq 'Python 3.12 through 3.15 is required' "${controller_bootstrap}"
grep -Fq 'sys.version_info[:2] <= (3, 15)' "${controller_bootstrap}"
grep -Fq 'Python 3.15 requires ansible-core 2.22.0 or newer' "${controller_bootstrap}"
grep -Fq 'Python 3.15 requires ansible-core 2.22.0 or newer' "${launcher}"
grep -Fq 'requires controller Python 3.13 through 3.15' "${controller_bootstrap}"
grep -Fq 'requires controller Python 3.13 through 3.15' "${launcher}"
grep -Fq 'LIBRENMS_PYTHON_315_PREVIEW_ENABLED' "${launcher}"
grep -Fq 'CONTROLLER_PYTHON_BASE_IMAGE' "${repo_root}/Dockerfile"
grep -Fq 'controller_python_for_ansible_core' "${repo_root}/scripts/ci-production-safety-check.py"
grep -Fq -- '--require-hashes' "${controller_bootstrap}"
grep -Fq 'ensure_controller_pip' "${controller_bootstrap}"
grep -Fq -- '-m ensurepip --upgrade' "${controller_bootstrap}"
grep -Fq 'apt install python${controller_python_version}-venv' "${controller_bootstrap}"

PYTHONPATH="${repo_root}/scripts${PYTHONPATH:+:${PYTHONPATH}}" \
    "${python_bin}" - <<'PY'
from ci_ansible_version import controller_python_for_ansible_core, parse_ansible_core_version

stable = parse_ansible_core_version("2.22.0")
release_candidate = parse_ansible_core_version("2.22.0rc1")
development = parse_ansible_core_version("2.22.0.dev0")
assert stable is not None and stable.stable and stable.release == (2, 22)
assert release_candidate is not None and not release_candidate.stable
assert development is not None and not development.stable
assert controller_python_for_ansible_core("2.22.0rc1") == "3.13"
assert parse_ansible_core_version("not-a-version") is None
PY

repair_venv="${temporary_dir}/controller-venv-without-pip"
empty_requirements="${temporary_dir}/empty-requirements.txt"
repair_output="${temporary_dir}/controller-repair.out"
# Keep a known pre-2.22 fixture so the Python 3.15 rejection remains covered
# even after the repository's production pin moves to a newer core release.
legacy_ansible_core_version="2.21.3"
printf 'ansible-core==%s\n' "${legacy_ansible_core_version}" > "${empty_requirements}"
# The controller bootstrap script intentionally targets the Linux venv layout
# (${venv_path}/bin/*). Use a small POSIX-shaped fixture so this test also runs
# from Git Bash on Windows, whose real venv layout is ${venv_path}/Scripts/*.
mkdir -p "${repair_venv}/bin"
cat > "${repair_venv}/bin/python" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="$(dirname -- "${BASH_SOURCE[0]}")/pip-installed"

if [ "${1:-}" = "-m" ] && [ "${2:-}" = "pip" ]; then
    case "${3:-}" in
        --version)
            [ -f "${state_file}" ] || exit 1
            printf 'pip 25.0\n'
            ;;
        install|check)
            touch "${state_file}"
            ;;
        *)
            exit 1
            ;;
    esac
    exit 0
fi

if [ "${1:-}" = "-m" ] && [ "${2:-}" = "ensurepip" ]; then
    touch "${state_file}"
    exit 0
fi

if [ "${1:-}" = "-c" ]; then
    printf '%s\n' "${FAKE_PYTHON_VERSION:-3.14}"
    exit 0
fi

printf 'Unexpected fake controller Python invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "${repair_venv}/bin/python"
cat > "${repair_venv}/bin/ansible-playbook" <<EOF
#!/usr/bin/env bash
printf 'ansible-playbook [core ${legacy_ansible_core_version}]\n'
EOF
chmod +x "${repair_venv}/bin/ansible-playbook"

FAKE_PYTHON_VERSION="${selected_python_version}" \
PYTHON_BIN="${python_bin}" \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${repair_venv}" \
LIBRENMS_ANSIBLE_CONTROLLER_REQUIREMENTS="${empty_requirements}" \
    "${controller_bootstrap}" >"${repair_output}"

grep -Fq 'Controller virtual environment is missing pip; attempting repair with ensurepip.' \
    "${repair_output}"
"${repair_venv}/bin/python" -m pip --version >/dev/null

python_315="${temporary_dir}/python-3.15"
python_315_bootstrap_output="${temporary_dir}/python-315-bootstrap.out"
python_315_dev_requirements="${temporary_dir}/python-315-dev-requirements.txt"
python_315_dev_bootstrap_output="${temporary_dir}/python-315-dev-bootstrap.out"
python_315_mismatch_venv="${temporary_dir}/controller-venv-python-mismatch"
python_315_mismatch_requirements="${temporary_dir}/python-315-mismatch-requirements.txt"
python_315_mismatch_output="${temporary_dir}/python-315-mismatch.out"
cat > "${python_315}" <<'EOF'
#!/usr/bin/env bash
printf '3.15\n'
EOF
chmod +x "${python_315}"

mkdir -p "${python_315_mismatch_venv}/bin"
cp "${repair_venv}/bin/python" "${python_315_mismatch_venv}/bin/python"
chmod +x "${python_315_mismatch_venv}/bin/python"
printf 'ansible-core==2.22.0\n' > "${python_315_mismatch_requirements}"
set +e
PYTHON_BIN="${python_315}" \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${python_315_mismatch_venv}" \
LIBRENMS_ANSIBLE_CONTROLLER_REQUIREMENTS="${python_315_mismatch_requirements}" \
    "${controller_bootstrap}" >"${python_315_mismatch_output}" 2>&1
bootstrap_315_mismatch_rc=$?
set -e

if [ "${bootstrap_315_mismatch_rc}" -eq 0 ]; then
    echo "Expected controller bootstrap to reject a mismatched existing Python virtual environment." >&2
    exit 1
fi
grep -Fq 'uses Python 3.14, but the selected bootstrap interpreter is Python 3.15' \
    "${python_315_mismatch_output}"

set +e
PYTHON_BIN="${python_315}" \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/unused-controller-venv" \
LIBRENMS_ANSIBLE_CONTROLLER_REQUIREMENTS="${controller_requirements}" \
    "${controller_bootstrap}" >"${python_315_bootstrap_output}" 2>&1
bootstrap_315_rc=$?
set -e

if [ "${bootstrap_315_rc}" -eq 0 ]; then
    echo "Expected controller bootstrap to reject Python 3.15 with ansible-core ${legacy_ansible_core_version}." >&2
    exit 1
fi
grep -Fq 'Python 3.15 requires ansible-core 2.22.0 or newer' \
    "${python_315_bootstrap_output}"

printf 'ansible-core==2.22.0.dev0\n' > "${python_315_dev_requirements}"
set +e
PYTHON_BIN="${python_315}" \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/unused-controller-venv-315-dev" \
LIBRENMS_ANSIBLE_CONTROLLER_REQUIREMENTS="${python_315_dev_requirements}" \
    "${controller_bootstrap}" >"${python_315_dev_bootstrap_output}" 2>&1
bootstrap_315_dev_rc=$?
set -e

if [ "${bootstrap_315_dev_rc}" -eq 0 ]; then
    echo "Expected controller bootstrap to reject an unapproved Python 3.15 development toolchain." >&2
    exit 1
fi
grep -Fq 'pre-release 2.22 builds require LIBRENMS_PYTHON_315_PREVIEW_ENABLED=true' \
    "${python_315_dev_bootstrap_output}"

# Force the launcher through its system-command fallback for the fake command
# assertions below, even when the checkout already has a controller venv.
export LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/missing-controller-venv"

fake_bin="${temporary_dir}/bin"
call_log="${temporary_dir}/calls.log"
collections_path="${temporary_dir}/collections"
mkdir -p "${fake_bin}"

cat > "${fake_bin}/ansible-galaxy" <<'EOF'
#!/usr/bin/env bash
printf 'galaxy' >> "${CALL_LOG}"
printf ' <%s>' "$@" >> "${CALL_LOG}"
printf ' mismatch-policy <%s>\n' \
    "${ANSIBLE_COLLECTIONS_ON_ANSIBLE_VERSION_MISMATCH:-}" >> "${CALL_LOG}"

fake_rc="${FAKE_GALAXY_EXIT:-0}"
if [ "${fake_rc}" -ne 0 ]; then
    exit "${fake_rc}"
fi

collections_root="${ANSIBLE_COLLECTIONS_PATH%%:*}"
write_manifest() {
    local namespace="$1"
    local collection="$2"
    local version="$3"
    local collection_dir="${collections_root}/ansible_collections/${namespace}/${collection}"

    mkdir -p "${collection_dir}"
    printf '{"collection_info":{"version":"%s"}}\n' "${version}" \
        > "${collection_dir}/MANIFEST.json"
}

write_manifest ansible posix 2.2.2
write_manifest community general 11.4.8
write_manifest ansible mariadb 6.0.2
EOF

cat > "${fake_bin}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
    printf 'ansible-playbook [core %s]\n' "${FAKE_ANSIBLE_CORE_VERSION:-2.21.3}"
    exit 0
fi

printf 'playbook' >> "${CALL_LOG}"
printf ' <%s>' "$@" >> "${CALL_LOG}"
printf '\nconfig <%s>\ncollections <%s>\n' \
    "${ANSIBLE_CONFIG:-}" \
    "${ANSIBLE_COLLECTIONS_PATH:-}" >> "${CALL_LOG}"
EOF

chmod +x "${fake_bin}/ansible-galaxy" "${fake_bin}/ansible-playbook"
export CALL_LOG="${call_log}"

launcher_315_output="${temporary_dir}/python-315-launcher.out"
export FAKE_ANSIBLE_CORE_VERSION="${controller_core_version}"
set +e
PYTHON_BIN="${python_315}" \
FAKE_ANSIBLE_CORE_VERSION="${legacy_ansible_core_version}" \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/missing-controller-venv-315" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml \
    >"${launcher_315_output}" 2>&1
launcher_315_rc=$?
set -e

if [ "${launcher_315_rc}" -eq 0 ]; then
    echo "Expected the launcher to reject Python 3.15 with ansible-core ${legacy_ansible_core_version}." >&2
    exit 1
fi
grep -Fq 'Python 3.15 requires ansible-core 2.22.0 or newer' \
    "${launcher_315_output}"

launcher_315_future_output="${temporary_dir}/python-315-future-launcher.out"
: > "${call_log}"
PYTHON_BIN="${python_315}" \
FAKE_ANSIBLE_CORE_VERSION=2.22.0 \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/missing-controller-venv-315-future" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml --check \
    >"${launcher_315_future_output}" 2>&1
grep -Fq 'playbook' "${call_log}"

launcher_315_dev_output="${temporary_dir}/python-315-dev-launcher.out"
: > "${call_log}"
set +e
PYTHON_BIN="${python_315}" \
FAKE_ANSIBLE_CORE_VERSION=2.22.0.dev0 \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/missing-controller-venv-315-dev" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml \
    >"${launcher_315_dev_output}" 2>&1
launcher_315_dev_rc=$?
set -e

if [ "${launcher_315_dev_rc}" -eq 0 ]; then
    echo "Expected the launcher to reject a Python 3.15 development controller by default." >&2
    exit 1
fi
grep -Fq 'pre-release 2.22 builds require LIBRENMS_PYTHON_315_PREVIEW_ENABLED=true' \
    "${launcher_315_dev_output}"
if grep -Fq 'playbook' "${call_log}"; then
    echo "The launcher started a playbook with an unapproved Python 3.15 pre-release controller." >&2
    exit 1
fi

launcher_315_preview_output="${temporary_dir}/python-315-preview-launcher.out"
: > "${call_log}"
LIBRENMS_PYTHON_315_PREVIEW_ENABLED=true \
PYTHON_BIN="${python_315}" \
FAKE_ANSIBLE_CORE_VERSION=2.22.0.dev0 \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/missing-controller-venv-315-preview" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml \
    >"${launcher_315_preview_output}" 2>&1
grep -Fq 'playbook' "${call_log}"

python_312="${temporary_dir}/python-3.12"
python_312_bootstrap_output="${temporary_dir}/python-312-bootstrap.out"
future_requirements="${temporary_dir}/future-requirements.txt"
cat > "${python_312}" <<'EOF'
#!/usr/bin/env bash
printf '3.12\n'
EOF
chmod +x "${python_312}"
printf 'ansible-core==2.22.0\n' > "${future_requirements}"

set +e
PYTHON_BIN="${python_312}" \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/unused-controller-venv-312" \
LIBRENMS_ANSIBLE_CONTROLLER_REQUIREMENTS="${future_requirements}" \
    "${controller_bootstrap}" >"${python_312_bootstrap_output}" 2>&1
bootstrap_312_rc=$?
set -e

if [ "${bootstrap_312_rc}" -eq 0 ]; then
    echo "Expected controller bootstrap to reject Python 3.12 with ansible-core 2.22.0." >&2
    exit 1
fi
grep -Fq 'requires controller Python 3.13 through 3.15' \
    "${python_312_bootstrap_output}"

launcher_312_output="${temporary_dir}/python-312-launcher.out"
: > "${call_log}"
set +e
PYTHON_BIN="${python_312}" \
FAKE_ANSIBLE_CORE_VERSION=2.22.0 \
LIBRENMS_ANSIBLE_CONTROLLER_VENV="${temporary_dir}/missing-controller-venv-312" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml \
    >"${launcher_312_output}" 2>&1
launcher_312_rc=$?
set -e

if [ "${launcher_312_rc}" -eq 0 ]; then
    echo "Expected the launcher to reject Python 3.12 with ansible-core 2.22.0." >&2
    exit 1
fi
grep -Fq 'requires controller Python 3.13 through 3.15' \
    "${launcher_312_output}"
if [ -s "${call_log}" ]; then
    echo "The launcher performed work after rejecting an unsupported controller Python." >&2
    exit 1
fi

PATH="${fake_bin}:${PATH}" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml --check

grep -Fq "galaxy <collection> <install> <-r> <${repo_root}/requirements.yml> <-p> <${collections_path}>" "${call_log}"
grep -Fq 'playbook <-i> <inventories/ha/hosts.yml> <playbooks/site.yml> <--check>' "${call_log}"
grep -Fq "config <${repo_root}/ansible.cfg>" "${call_log}"
grep -Fq "collections <${collections_path}>" "${call_log}"
"${python_bin}" "${collection_state_checker}" \
    --requirements "${collection_requirements}" \
    --collections-path "${collections_path}" \
    --require-installed

if grep -Fq '<--force>' "${call_log}"; then
    echo "A first-time collection install must not require a forced refresh." >&2
    exit 1
fi

write_manifest "${collections_path}" community general 13.2.0
: > "${call_log}"
PATH="${fake_bin}:${PATH}" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml --check

grep -Fq '<--force>' "${call_log}"
grep -Fq 'mismatch-policy <ignore>' "${call_log}"
"${python_bin}" "${collection_state_checker}" \
    --requirements "${collection_requirements}" \
    --collections-path "${collections_path}" \
    --require-installed

: > "${call_log}"
PATH="${fake_bin}:${PATH}" \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml --check

if grep -Fq '<--force>' "${call_log}"; then
    echo "Converged collection pins must not be force-reinstalled." >&2
    exit 1
fi

if grep -Fq 'mismatch-policy <ignore>' "${call_log}"; then
    echo "Compatibility warnings must remain enabled after collection convergence." >&2
    exit 1
fi

: > "${call_log}"
set +e
PATH="${fake_bin}:${PATH}" \
FAKE_GALAXY_EXIT=23 \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml >/dev/null 2>&1
launcher_rc=$?
set -e

if [ "${launcher_rc}" -eq 0 ]; then
    echo "Expected the launcher to fail when collection installation fails." >&2
    exit 1
fi

if grep -Fq 'playbook' "${call_log}"; then
    echo "The launcher started a playbook after collection installation failed." >&2
    exit 1
fi

: > "${call_log}"
old_core_output="${temporary_dir}/old-core.out"
set +e
PATH="${fake_bin}:${PATH}" \
FAKE_ANSIBLE_CORE_VERSION=2.19.7 \
LIBRENMS_ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
ANSIBLE_GALAXY_BIN="${fake_bin}/ansible-galaxy" \
ANSIBLE_PLAYBOOK_BIN="${fake_bin}/ansible-playbook" \
    "${launcher}" -i inventories/ha/hosts.yml playbooks/site.yml \
    >"${old_core_output}" 2>&1
launcher_rc=$?
set -e

if [ "${launcher_rc}" -eq 0 ]; then
    echo "Expected the launcher to reject ansible-core older than 2.20." >&2
    exit 1
fi

grep -Fq 'ansible-core 2.20.0+ is required' "${old_core_output}"
if [ -s "${call_log}" ]; then
    echo "The launcher performed work after rejecting an old ansible-core." >&2
    exit 1
fi

echo "Controller collection bootstrap tests passed."
