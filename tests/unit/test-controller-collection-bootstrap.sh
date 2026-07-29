#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
launcher="${repo_root}/scripts/ansible-playbook.sh"
ansible_config="${repo_root}/ansible.cfg"
collection_requirements="${repo_root}/requirements.yml"
collection_state_checker="${repo_root}/scripts/ansible-collection-state.py"
python_bin="${PYTHON_BIN:-python3}"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT

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
write_manifest ansible mysql 5.2.0
EOF

cat > "${fake_bin}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
printf 'playbook' >> "${CALL_LOG}"
printf ' <%s>' "$@" >> "${CALL_LOG}"
printf '\nconfig <%s>\ncollections <%s>\n' \
    "${ANSIBLE_CONFIG:-}" \
    "${ANSIBLE_COLLECTIONS_PATH:-}" >> "${CALL_LOG}"
EOF

chmod +x "${fake_bin}/ansible-galaxy" "${fake_bin}/ansible-playbook"
export CALL_LOG="${call_log}"

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

echo "Controller collection bootstrap tests passed."
