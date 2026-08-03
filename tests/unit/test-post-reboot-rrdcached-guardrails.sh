#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly POST_REBOOT_TASKS="${ROOT_DIR}/roles/post_reboot/tasks/main.yml"
readonly STARTUP_REPAIR_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"
readonly RRDCACHED_OVERRIDE="${ROOT_DIR}/roles/librenms_app/templates/rrdcached.systemd-override.conf.j2"

fail() {
    printf 'Post-reboot RRDCacheD guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_file_text() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "$expected" "$file" || fail "missing ${expected} in ${file}"
}

line_number() {
    local file="$1"
    local needle="$2"
    grep -nF -- "$needle" "$file" | head -n 1 | cut -d: -f1
}

main() {
    local mount_wait_line
    local writable_repair_line
    local rrdcached_start_line
    local rrdcached_verify_line
    local rrdcached_fail_line
    local skip_line
    local startup_mount_line
    local startup_writable_line
    local startup_start_line

    require_file_text "$POST_REBOOT_TASKS" \
        'librenms_post_reboot_rrdcached_nodes'
    require_file_text "$POST_REBOOT_TASKS" \
        'Trigger RRD mount repair before managed RRDCacheD convergence'
    require_file_text "$POST_REBOOT_TASKS" \
        'Reset failed managed RRDCacheD state after reboot'
    require_file_text "$POST_REBOOT_TASKS" \
        'Enable and start managed RRDCacheD after reboot'
    require_file_text "$POST_REBOOT_TASKS" \
        'Verify managed RRDCacheD is active after reboot'
    require_file_text "$POST_REBOOT_TASKS" \
        'Fail when managed RRDCacheD remains unavailable after reboot repair'
    require_file_text "$STARTUP_REPAIR_TEMPLATE" \
        'wait_for_rrd_mount || true'
    require_file_text "$STARTUP_REPAIR_TEMPLATE" \
        'repair_writable_paths'
    require_file_text "$STARTUP_REPAIR_TEMPLATE" \
        'ensure_rrdcached || true'
    require_file_text "$RRDCACHED_OVERRIDE" 'Restart=on-failure'
    require_file_text "$RRDCACHED_OVERRIDE" 'RestartSec=5s'
    require_file_text "$RRDCACHED_OVERRIDE" 'StartLimitIntervalSec=300'
    require_file_text "$RRDCACHED_OVERRIDE" 'StartLimitBurst=6'

    skip_line="$(line_number "$STARTUP_REPAIR_TEMPLATE" \
        'if [ "${RRD_MODE}" = "glusterfs" ] && [ "${unit}" = "${RRDCACHED_SERVICE}" ]; then')"
    startup_mount_line="$(line_number "$STARTUP_REPAIR_TEMPLATE" \
        'wait_for_rrd_mount || true')"
    startup_writable_line="$(line_number "$STARTUP_REPAIR_TEMPLATE" \
        'repair_writable_paths')"
    startup_start_line="$(line_number "$STARTUP_REPAIR_TEMPLATE" \
        'ensure_rrdcached || true')"

    [[ -n "$skip_line" && -n "$startup_mount_line" \
        && -n "$startup_writable_line" && -n "$startup_start_line" ]] || \
        fail 'could not locate startup RRDCacheD ordering markers'

    ((skip_line < startup_mount_line)) || \
        fail 'Gluster RRDCacheD must be skipped during the generic service loop'
    ((startup_mount_line < startup_writable_line \
        && startup_writable_line < startup_start_line)) || \
        fail 'RRD mount and writable-path repair must precede RRDCacheD start'

    mount_wait_line="$(line_number "$POST_REBOOT_TASKS" \
        'Trigger RRD mount repair before managed RRDCacheD convergence')"
    rrdcached_start_line="$(line_number "$POST_REBOOT_TASKS" \
        'Enable and start managed RRDCacheD after reboot')"
    rrdcached_verify_line="$(line_number "$POST_REBOOT_TASKS" \
        'Verify managed RRDCacheD is active after reboot')"
    rrdcached_fail_line="$(line_number "$POST_REBOOT_TASKS" \
        'Fail when managed RRDCacheD remains unavailable after reboot repair')"

    [[ -n "$mount_wait_line" && -n "$rrdcached_start_line" \
        && -n "$rrdcached_verify_line" && -n "$rrdcached_fail_line" ]] || \
        fail 'could not locate post-reboot RRDCacheD ordering markers'

    ((mount_wait_line < rrdcached_start_line \
        && rrdcached_start_line < rrdcached_verify_line \
        && rrdcached_verify_line < rrdcached_fail_line)) || \
        fail 'post-reboot RRDCacheD repair must run before verification and HA status'

    printf 'Post-reboot RRDCacheD guardrail test passed.\n'
}

main "$@"
