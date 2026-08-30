#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TASKS="${ROOT_DIR}/roles/maintenance/tasks/enter.yml"
readonly DEFAULTS="${ROOT_DIR}/roles/maintenance/defaults/main.yml"
readonly MAIN_TASKS="${ROOT_DIR}/roles/maintenance/tasks/main.yml"
readonly EXIT_TASKS="${ROOT_DIR}/roles/maintenance/tasks/exit.yml"
readonly HOLD_PLAYBOOK="${ROOT_DIR}/playbooks/maintenance-hold.yml"
readonly STATUS_DEFAULTS="${ROOT_DIR}/roles/ha_status/defaults/main.yml"
readonly STATUS_TASKS="${ROOT_DIR}/roles/ha_status/tasks/main.yml"

fail() {
    printf 'Maintenance stop guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_file_text() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "${expected}" "${file}" ||
        fail "missing ${expected} in ${file}"
}

main() {
    require_file_text "${DEFAULTS}" \
        'librenms_maintenance_systemctl_timeout: 10'
    require_file_text "${DEFAULTS}" \
        'librenms_maintenance_unit_stop_timeout: 30'
    require_file_text "${DEFAULTS}" \
        'librenms_maintenance_unit_kill_grace: 5'
    require_file_text "${DEFAULTS}" \
        'librenms_maintenance_stop_haproxy: true'
    require_file_text "${DEFAULTS}" \
        'librenms_maintenance_stop_glusterd: true'
    require_file_text "${TASKS}" 'systemctl_bounded()'
    require_file_text "${TASKS}" 'unit_exists()'
    require_file_text "${TASKS}" 'wait_until_stopped()'
    require_file_text "${TASKS}" 'systemctl_bounded stop --no-block "${stop_unit}"'
    require_file_text "${TASKS}" \
        'systemctl_bounded kill --kill-whom=all --signal=TERM "${stop_unit}"'
    require_file_text "${TASKS}" \
        'systemctl_bounded kill --kill-whom=all --signal=KILL "${stop_unit}"'
    require_file_text "${TASKS}" 'print_stop_diagnostics()'
    require_file_text "${TASKS}" 'Stop target HAProxy before maintenance'
    require_file_text "${TASKS}" 'librenms_maintenance_stop_haproxy | bool'
    require_file_text "${TASKS}" 'Stop target glusterd before maintenance'
    require_file_text "${TASKS}" 'librenms_maintenance_stop_glusterd | bool'
    require_file_text "${TASKS}" 'librenms-ha-startup-repair.timer'
    require_file_text "${TASKS}" 'librenms-dispatcher-ha-recover.timer'
    require_file_text "${MAIN_TASKS}" \
        "librenms_maintenance_action in ['enter', 'exit', 'hold']"
    require_file_text "${MAIN_TASKS}" \
        "difference(groups.get('maintenance_nodes', []))"
    require_file_text "${HOLD_PLAYBOOK}" 'hosts: maintenance_nodes'
    require_file_text "${HOLD_PLAYBOOK}" \
        'librenms_maintenance_action: hold'
    require_file_text "${EXIT_TASKS}" \
        'Resume target HA repair timers after maintenance'
    require_file_text "${STATUS_DEFAULTS}" \
        'librenms-ha-startup-repair.service'
    require_file_text "${STATUS_DEFAULTS}" \
        'librenms-dispatcher-ha-recover.service'
    require_file_text "${STATUS_TASKS}" \
        "in ['active', 'activating', 'reloading', 'deactivating']"

    if grep -Fq -- 'systemctl stop "$unit"' "${TASKS}"; then
        fail 'maintenance workers must not use an unbounded synchronous unit stop'
    fi

    printf 'Maintenance stop guardrail test passed.\n'
}

main "$@"
