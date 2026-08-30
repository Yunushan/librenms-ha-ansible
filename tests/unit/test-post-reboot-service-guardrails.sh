#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TASKS="${ROOT_DIR}/roles/post_reboot/tasks/main.yml"
readonly DEFAULTS="${ROOT_DIR}/roles/post_reboot/defaults/main.yml"

fail() {
    printf 'Post-reboot service guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_file_text() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "${expected}" "${file}" ||
        fail "missing ${expected} in ${file}"
}

line_number() {
    local file="$1"
    local needle="$2"

    awk -v needle="${needle}" 'index($0, needle) { print NR; exit }' "${file}"
}

main() {
    local start_line
    local wait_line
    local rescue_line

    require_file_text "${DEFAULTS}" \
        'librenms_post_reboot_systemctl_timeout: 20'
    require_file_text "${TASKS}" 'Ensure HAProxy is active after reboot'
    require_file_text "${TASKS}" 'systemctl'
    require_file_text "${TASKS}" 'reset-failed'
    require_file_text "${TASKS}" 'Validate HAProxy configuration after reboot'
    require_file_text "${TASKS}" 'Start HAProxy after reboot'
    require_file_text "${TASKS}" 'Wait for HAProxy after reboot'
    require_file_text "${TASKS}" 'Capture HAProxy status after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Capture HAProxy journal after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Capture HAProxy listeners after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Fail with HAProxy post-reboot diagnostics'
    require_file_text "${TASKS}" '--no-block'
    require_file_text "${TASKS}" 'haproxy -c:'

    start_line="$(line_number "${TASKS}" 'Start HAProxy after reboot')"
    wait_line="$(line_number "${TASKS}" 'Wait for HAProxy after reboot')"
    rescue_line="$(line_number "${TASKS}" 'Capture HAProxy status after failed post-reboot recovery')"

    [[ -n "${start_line}" && -n "${wait_line}" && -n "${rescue_line}" ]] ||
        fail 'could not locate HAProxy recovery boundaries'
    ((start_line < wait_line && wait_line < rescue_line)) ||
        fail 'HAProxy must be started and waited for before diagnostics'

    printf 'Post-reboot service guardrail test passed.\n'
}

main "$@"
