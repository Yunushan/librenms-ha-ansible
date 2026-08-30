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
    local when_line
    local block_line
    local rescue_line

    require_file_text "${DEFAULTS}" \
        'librenms_post_reboot_systemctl_timeout: 20'
    require_file_text "${DEFAULTS}" \
        'librenms_post_reboot_mariadb_retries: 30'
    require_file_text "${DEFAULTS}" \
        'librenms_post_reboot_mariadb_delay: 10'
    require_file_text "${TASKS}" 'Ensure HAProxy is active after reboot'
    require_file_text "${TASKS}" 'Reconcile HAProxy non-local VIP binding after reboot'
    require_file_text "${TASKS}" 'net.ipv4.ip_nonlocal_bind'
    require_file_text "${TASKS}" 'systemctl'
    require_file_text "${TASKS}" 'reset-failed'
    require_file_text "${TASKS}" 'Validate HAProxy configuration after reboot'
    require_file_text "${TASKS}" 'Start HAProxy after reboot'
    require_file_text "${TASKS}" 'Wait for HAProxy after reboot'
    require_file_text "${TASKS}" 'Capture HAProxy status after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Capture HAProxy journal after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Capture HAProxy listeners after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Capture HAProxy non-local bind state after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Capture HAProxy service properties after failed post-reboot recovery'
    require_file_text "${TASKS}" 'Fail with HAProxy post-reboot diagnostics'
    require_file_text "${TASKS}" 'haproxy -c:'
    require_file_text "${TASKS}" 'Ensure MariaDB reaches an active state after reboot'
    require_file_text "${TASKS}" 'Wait while MariaDB is starting after reboot'
    require_file_text "${TASKS}" 'Verify MariaDB is active after reboot'
    require_file_text "${TASKS}" 'TimeoutStartUSec'
    require_file_text "${TASKS}" 'Capture MariaDB unit definition after failed post-reboot convergence'
    require_file_text "${TASKS}" 'Capture MariaDB current-boot journal after failed post-reboot convergence'
    require_file_text "${TASKS}" 'Capture local Galera state after failed post-reboot convergence'
    require_file_text "${TASKS}" 'Fail with MariaDB post-reboot diagnostics'
    require_file_text "${TASKS}" 'No Galera bootstrap or recovered-position mutation was attempted.'

    if grep -Eq 'galera_new_cluster|--wsrep-new-cluster|safe_to_bootstrap' "${TASKS}"; then
        fail 'post-reboot convergence must never bootstrap or mutate Galera recovery state'
    fi

    start_line="$(line_number "${TASKS}" 'Start HAProxy after reboot')"
    wait_line="$(line_number "${TASKS}" 'Wait for HAProxy after reboot')"
    when_line="$(line_number "${TASKS}" 'when: inventory_hostname in librenms_post_reboot_active_lb_nodes')"
    block_line="$(line_number "${TASKS}" '  block:')"
    rescue_line="$(line_number "${TASKS}" 'Capture HAProxy status after failed post-reboot recovery')"

    [[ -n "${start_line}" && -n "${wait_line}" && -n "${when_line}" &&
        -n "${block_line}" && -n "${rescue_line}" ]] ||
        fail 'could not locate HAProxy recovery boundaries'
    ((when_line < block_line)) ||
        fail 'HAProxy block condition must precede block for Ansible key ordering'
    ((start_line < wait_line && wait_line < rescue_line)) ||
        fail 'HAProxy must be started and waited for before diagnostics'

    printf 'Post-reboot service guardrail test passed.\n'
}

main "$@"
