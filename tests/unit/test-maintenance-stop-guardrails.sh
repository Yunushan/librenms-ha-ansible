#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TASKS="${ROOT_DIR}/roles/maintenance/tasks/enter.yml"
readonly DEFAULTS="${ROOT_DIR}/roles/maintenance/defaults/main.yml"

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
    require_file_text "${TASKS}" 'systemctl_bounded()'
    require_file_text "${TASKS}" 'unit_exists()'
    require_file_text "${TASKS}" 'wait_until_stopped()'
    require_file_text "${TASKS}" 'systemctl_bounded stop --no-block "${stop_unit}"'
    require_file_text "${TASKS}" \
        'systemctl_bounded kill --kill-whom=all --signal=TERM "${stop_unit}"'
    require_file_text "${TASKS}" \
        'systemctl_bounded kill --kill-whom=all --signal=KILL "${stop_unit}"'
    require_file_text "${TASKS}" 'print_stop_diagnostics()'

    if grep -Fq -- 'systemctl stop "$unit"' "${TASKS}"; then
        fail 'maintenance workers must not use an unbounded synchronous unit stop'
    fi

    printf 'Maintenance stop guardrail test passed.\n'
}

main "$@"
