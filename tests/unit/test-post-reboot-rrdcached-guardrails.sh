#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly POST_REBOOT_TASKS="${ROOT_DIR}/roles/post_reboot/tasks/main.yml"
readonly POST_REBOOT_PLAYBOOK="${ROOT_DIR}/playbooks/post-reboot.yml"
readonly DEFAULTS="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly HA_STATUS_TASKS="${ROOT_DIR}/roles/ha_status/tasks/main.yml"
readonly STARTUP_REPAIR_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"
readonly RRDCACHED_OVERRIDE="${ROOT_DIR}/roles/librenms_app/templates/rrdcached.systemd-override.conf.j2"
readonly RRDCACHED_SOCKET_OVERRIDE="${ROOT_DIR}/roles/librenms_app/templates/rrdcached.socket.systemd-override.conf.j2"

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
    awk -v needle="$needle" 'index($0, needle) { print NR; exit }' "$file"
}

last_line_number() {
    local file="$1"
    local needle="$2"
    awk -v needle="$needle" 'index($0, needle) { line=NR } END { if (line) print line }' "$file"
}

main() {
    local mount_wait_line
    local mount_verify_line
    local active_nodes_line
    local rrdcached_nodes_task_line
    local rrdcached_nodes_line
    local writable_repair_line
    local rrdcached_start_line
    local rrdcached_verify_line
    local rrdcached_fail_line
    local skip_line
    local startup_mount_line
    local startup_writable_line
    local startup_start_line
    local post_reboot_role_line
    local ha_status_play_line
    local ha_status_role_line

    require_file_text "$POST_REBOOT_TASKS" \
        'librenms_post_reboot_rrdcached_nodes'
    require_file_text "$POST_REBOOT_TASKS" \
        'Build managed RRDCacheD host list for post-reboot convergence'
    require_file_text "$POST_REBOOT_TASKS" \
        'Trigger RRD mount repair before managed RRDCacheD convergence'
    require_file_text "$POST_REBOOT_TASKS" \
        'Lazily detach inaccessible Gluster RRD mount after reboot'
    require_file_text "$POST_REBOOT_TASKS" \
        'librenms_post_reboot_rrd_mount_detached'
    require_file_text "$POST_REBOOT_TASKS" \
        'Restore Gluster RRD mount definition after reboot'
    require_file_text "$POST_REBOOT_TASKS" \
        'librenms_gluster_mount_attempt_timeout'
    require_file_text "$POST_REBOOT_TASKS" \
        'Verify shared RRD mount before managed RRDCacheD startup'
    require_file_text "$POST_REBOOT_TASKS" \
        'Fail when shared RRD mount recovery does not converge'
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
        'timeout "${GLUSTER_MOUNT_ATTEMPT_TIMEOUT}"'
    require_file_text "$STARTUP_REPAIR_TEMPLATE" \
        'repair_writable_paths'
    require_file_text "$STARTUP_REPAIR_TEMPLATE" \
        'ensure_rrdcached || true'
    require_file_text "$RRDCACHED_OVERRIDE" 'Restart=on-failure'
    require_file_text "$RRDCACHED_OVERRIDE" 'RestartSec=5s'
    require_file_text "$RRDCACHED_OVERRIDE" 'KillMode=control-group'
    require_file_text "$RRDCACHED_OVERRIDE" 'SendSIGKILL=yes'
    require_file_text "$RRDCACHED_OVERRIDE" 'TimeoutStopSec=30s'
    require_file_text "$RRDCACHED_OVERRIDE" 'ExecStop='
    require_file_text "$RRDCACHED_OVERRIDE" 'StartLimitIntervalSec=300'
    require_file_text "$RRDCACHED_OVERRIDE" 'StartLimitBurst=6'
    require_file_text "$RRDCACHED_SOCKET_OVERRIDE" 'ListenStream='
    require_file_text "$RRDCACHED_SOCKET_OVERRIDE" 'ListenStream={{ librenms_rrdcached_socket }}'
    require_file_text "$RRDCACHED_SOCKET_OVERRIDE" 'ListenStream={{ librenms_rrdcached_network_bind_address_effective }}:{{ librenms_rrdcached_bind_port }}'
    require_file_text "$DEFAULTS" 'librenms_gluster_mount_attempt_timeout: 30'
    require_file_text "$HA_STATUS_TASKS" \
        '--mountpoint {{ (librenms_install_dir ~ '\''/rrd'\'') | quote }}'
    require_file_text "$HA_STATUS_TASKS" \
        ") not in ['glusterfs', 'fuse.glusterfs']"
    require_file_text "$POST_REBOOT_PLAYBOOK" \
        'Verify LibreNMS HA status after post-reboot convergence'

    post_reboot_role_line="$(line_number "$POST_REBOOT_PLAYBOOK" \
        '    - role: post_reboot')"
    ha_status_play_line="$(line_number "$POST_REBOOT_PLAYBOOK" \
        'Verify LibreNMS HA status after post-reboot convergence')"
    ha_status_role_line="$(line_number "$POST_REBOOT_PLAYBOOK" \
        '    - role: ha_status')"

    [[ -n "$post_reboot_role_line" && -n "$ha_status_play_line" \
        && -n "$ha_status_role_line" ]] || \
        fail 'could not locate post-reboot convergence and HA status play boundaries'

    ((post_reboot_role_line < ha_status_play_line \
        && ha_status_play_line < ha_status_role_line)) || \
        fail 'HA status must run in a separate play after post-reboot convergence'

    active_nodes_line="$(line_number "$POST_REBOOT_TASKS" \
        'librenms_post_reboot_active_nodes:')"
    rrdcached_nodes_task_line="$(line_number "$POST_REBOOT_TASKS" \
        'Build managed RRDCacheD host list for post-reboot convergence')"
    rrdcached_nodes_line="$(line_number "$POST_REBOOT_TASKS" \
        'librenms_post_reboot_rrdcached_nodes:')"

    [[ -n "$active_nodes_line" && -n "$rrdcached_nodes_task_line" \
        && -n "$rrdcached_nodes_line" ]] || \
        fail 'could not locate post-reboot host-list fact boundaries'

    ((active_nodes_line < rrdcached_nodes_task_line \
        && rrdcached_nodes_task_line < rrdcached_nodes_line)) || \
        fail 'RRDCacheD host selection must run after active-node facts are committed'

    skip_line="$(line_number "$STARTUP_REPAIR_TEMPLATE" \
        'if [ "${RRD_MODE}" = "glusterfs" ] && [ "${unit}" = "${RRDCACHED_SERVICE}" ]; then')"
    startup_mount_line="$(line_number "$STARTUP_REPAIR_TEMPLATE" \
        'wait_for_rrd_mount || true')"
    startup_writable_line="$(last_line_number "$STARTUP_REPAIR_TEMPLATE" \
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
    mount_verify_line="$(line_number "$POST_REBOOT_TASKS" \
        'Verify shared RRD mount before managed RRDCacheD startup')"
    rrdcached_start_line="$(line_number "$POST_REBOOT_TASKS" \
        'Enable and start managed RRDCacheD after reboot')"
    rrdcached_verify_line="$(line_number "$POST_REBOOT_TASKS" \
        'Verify managed RRDCacheD is active after reboot')"
    rrdcached_fail_line="$(line_number "$POST_REBOOT_TASKS" \
        'Fail when managed RRDCacheD remains unavailable after reboot repair')"

    [[ -n "$mount_wait_line" && -n "$mount_verify_line" \
        && -n "$rrdcached_start_line" \
        && -n "$rrdcached_verify_line" && -n "$rrdcached_fail_line" ]] || \
        fail 'could not locate post-reboot RRDCacheD ordering markers'

    ((mount_wait_line < mount_verify_line \
        && mount_verify_line < rrdcached_start_line \
        && rrdcached_start_line < rrdcached_verify_line \
        && rrdcached_verify_line < rrdcached_fail_line)) || \
        fail 'post-reboot shared RRD verification must gate RRDCacheD startup'

    printf 'Post-reboot RRDCacheD guardrail test passed.\n'
}

main "$@"
