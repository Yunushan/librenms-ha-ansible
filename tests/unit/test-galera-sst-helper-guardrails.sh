#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly HELPER_TASKS="${ROOT_DIR}/roles/galera_sst_helper/tasks/main.yml"
readonly REPAIR_TASKS="${ROOT_DIR}/roles/galera_sst_repair/tasks/main.yml"
readonly REPAIR_PLAYBOOK="${ROOT_DIR}/playbooks/galera-sst-repair.yml"
readonly POST_REBOOT_PLAYBOOK="${ROOT_DIR}/playbooks/post-reboot.yml"
readonly SITE_PLAYBOOK="${ROOT_DIR}/playbooks/site.yml"
readonly PACKAGE_SMOKE="${ROOT_DIR}/tests/platform/package-smoke.sh"
readonly MAKEFILE="${ROOT_DIR}/Makefile"

fail() {
    printf 'Galera SST helper guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "${expected}" "${file}" ||
        fail "missing ${expected} in ${file}"
}

main() {
    require_text "${DEFAULTS}" 'librenms_galera_sst_helper_path:'
    require_text "${DEFAULTS}" 'librenms_galera_sst_helper_mode: "0755"'
    require_text "${HELPER_TASKS}" 'Reconcile package-owned Galera SST helper permissions'
    require_text "${HELPER_TASKS}" 'Verify the Galera SST helper is executable'
    require_text "${HELPER_TASKS}" 'Reject a noexec Galera SST helper filesystem'
    require_text "${REPAIR_TASKS}" 'Require a healthy Primary quorum before SST helper repair'
    require_text "${REPAIR_TASKS}" 'ansible_play_hosts_all | length == 1'
    require_text "${REPAIR_TASKS}" '--no-block'
    require_text "${REPAIR_TASKS}" 'Wait for Primary and Synced state after SST helper repair'
    require_text "${REPAIR_TASKS}" 'No bootstrap, recovered-position mutation, or datadir deletion was attempted.'
    require_text "${REPAIR_PLAYBOOK}" 'role: galera_sst_repair'
    require_text "${POST_REBOOT_PLAYBOOK}" 'role: galera_sst_helper'
    require_text "${SITE_PLAYBOOK}" 'role: galera_sst_helper'
    require_text "${PACKAGE_SMOKE}" 'wsrep_sst_rsync'
    require_text "${MAKEFILE}" 'galera-sst-repair-ask-become-pass:'

    if grep -Eq -- 'galera_new_cluster|--wsrep-new-cluster|safe_to_bootstrap|grastate\.dat|rm -rf' \
        "${REPAIR_TASKS}"; then
        fail 'SST helper repair must not contain bootstrap or destructive datadir operations'
    fi

    printf 'Galera SST helper guardrail test passed.\n'
}

main "$@"
