#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
launcher="${repo_root}/scripts/ansible-playbook.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT

fake_bin="${temporary_dir}/bin"
call_log="${temporary_dir}/calls.log"
collections_path="${temporary_dir}/collections"
mkdir -p "${fake_bin}"

cat > "${fake_bin}/ansible-galaxy" <<'EOF'
#!/usr/bin/env bash
printf 'galaxy' >> "${CALL_LOG}"
printf ' <%s>' "$@" >> "${CALL_LOG}"
printf '\n' >> "${CALL_LOG}"
exit "${FAKE_GALAXY_EXIT:-0}"
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
