#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKS_FILE="$ROOT_DIR/roles/glusterfs_rrd/tasks/main.yml"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"
RUNTIME_WAIT_TEMPLATE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-runtime-wait.sh.j2"
STARTUP_REPAIR_TEMPLATE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"
RRD_PERMISSION_REPAIR_TEMPLATE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-rrd-permission-repair.sh.j2"

require_text() {
    local expected="$1"

    if ! grep -Fq -- "$expected" "$TASKS_FILE"; then
        printf 'Missing expected Gluster RRD mount guardrail: %s\n' "$expected" >&2
        exit 1
    fi
}

require_file_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Missing expected Gluster RRD guardrail in %s: %s\n' \
            "$file" "$expected" >&2
        exit 1
    fi
}

require_text "Detect active Gluster-backed RRD mount on LibreNMS nodes"
require_text "--nocanonicalize"
require_text "--mountpoint"
require_text "Inspect unmounted RRD mountpoint path on LibreNMS nodes"
require_text "follow: false"
require_text "Refuse unsafe non-directory RRD mountpoint paths"
require_text "Remove legacy RRD mountpoint symlink without deleting its target"
require_text "Ensure unmounted RRD mountpoint exists on LibreNMS nodes"
require_text "Probe active Gluster-backed RRD mount accessibility"
require_text "Record stale Gluster-backed RRD client mount state"
require_text "Stop active RRDCacheD before stale Gluster RRD mount recovery"
require_text "Lazily detach stale Gluster-backed RRD client mount"
require_text "Verify stale Gluster-backed RRD mount was detached"
require_text "Verify prepared unmounted RRD mountpoint is a real directory"
require_text "Verify mounted Gluster-backed RRD path is accessible"
require_text "Restore RRDCacheD after stale Gluster RRD mount recovery"
require_text "--dereference"
require_text "--lazy"

require_file_text "$DEFAULTS_FILE" \
    "librenms_gluster_recover_stale_client_mounts: true"
require_file_text "$STARTUP_REPAIR_TEMPLATE" "recover_stale_rrd_mount()"
require_file_text "$STARTUP_REPAIR_TEMPLATE" \
    'RRD_PATH={{ librenms_rrdcached_base_path | quote }}'
require_file_text "$STARTUP_REPAIR_TEMPLATE" \
    'umount --lazy -- "${RRD_PATH}"'
require_file_text "$STARTUP_REPAIR_TEMPLATE" \
    'systemctl stop "${RRDCACHED_SERVICE}"'
require_file_text "$STARTUP_REPAIR_TEMPLATE" \
    'systemctl start "${RRDCACHED_SERVICE}"'
require_file_text "$RUNTIME_WAIT_TEMPLATE" "--nocanonicalize"
require_file_text "$RUNTIME_WAIT_TEMPLATE" \
    'RRD_PATH={{ librenms_rrdcached_base_path | quote }}'
require_file_text "$RUNTIME_WAIT_TEMPLATE" \
    'stat --dereference --format=%F'
require_file_text "$RRD_PERMISSION_REPAIR_TEMPLATE" \
    'RRD_PATH={{ librenms_rrdcached_base_path | quote }}'

first_line_number() {
    local file="$1"
    local needle="$2"
    awk -v needle="$needle" 'index($0, needle) { print NR; exit }' "$file"
}

last_line_number() {
    local file="$1"
    local needle="$2"
    awk -v needle="$needle" 'index($0, needle) { line=NR } END { if (line) print line }' "$file"
}

startup_main_mount_wait_line="$(first_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'wait_for_rrd_mount || true')"
startup_writable_repair_line="$(last_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'repair_writable_paths')"

if [[ -z "$startup_main_mount_wait_line" \
    || -z "$startup_writable_repair_line" \
    || "$startup_main_mount_wait_line" -ge "$startup_writable_repair_line" ]]; then
    printf 'Startup stale-mount recovery must run independently before writable ownership repair.\n' >&2
    exit 1
fi

startup_health_line="$(first_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'rrd_path_accessible && return 0')"
startup_enable_line="$(last_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'GLUSTER_STALE_MOUNT_RECOVERY')"
startup_stop_line="$(first_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'systemctl stop "${RRDCACHED_SERVICE}"')"
startup_unmount_line="$(first_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'umount --lazy -- "${RRD_PATH}"')"
startup_mount_line="$(first_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'mount_rrd_path || return 1')"
startup_start_line="$(first_line_number "$STARTUP_REPAIR_TEMPLATE" \
    'systemctl start "${RRDCACHED_SERVICE}"')"

if ((startup_health_line >= startup_enable_line \
    || startup_enable_line >= startup_stop_line \
    || startup_stop_line >= startup_unmount_line \
    || startup_unmount_line >= startup_mount_line \
    || startup_mount_line >= startup_start_line)); then
    printf 'Automatic stale-mount recovery must verify, drain, detach, remount, then restore RRDCacheD.\n' >&2
    exit 1
fi

detect_line="$(first_line_number "$TASKS_FILE" \
    'Detect active Gluster-backed RRD mount')"
health_line="$(first_line_number "$TASKS_FILE" \
    'Probe active Gluster-backed RRD mount accessibility')"
detach_line="$(first_line_number "$TASKS_FILE" \
    'Lazily detach stale Gluster-backed RRD client mount')"
redetect_line="$(first_line_number "$TASKS_FILE" \
    'Re-detect Gluster-backed RRD mount after stale mount recovery')"
inspect_line="$(first_line_number "$TASKS_FILE" \
    'Inspect unmounted RRD mountpoint path')"
unlink_line="$(first_line_number "$TASKS_FILE" \
    'Remove legacy RRD mountpoint symlink')"
ensure_line="$(first_line_number "$TASKS_FILE" \
    'Ensure unmounted RRD mountpoint exists')"
prepared_line="$(first_line_number "$TASKS_FILE" \
    'Verify prepared unmounted RRD mountpoint')"
mount_line="$(first_line_number "$TASKS_FILE" \
    'Mount GlusterFS volume on LibreNMS nodes')"
mounted_health_line="$(first_line_number "$TASKS_FILE" \
    'Verify mounted Gluster-backed RRD path is accessible')"
restore_line="$(first_line_number "$TASKS_FILE" \
    'Restore RRDCacheD after stale Gluster RRD mount recovery')"
nocanonicalize_line="$(first_line_number "$TASKS_FILE" '--nocanonicalize')"
mountpoint_option_line="$(first_line_number "$TASKS_FILE" '--mountpoint')"

if ((nocanonicalize_line >= mountpoint_option_line)); then
    printf 'findmnt must disable canonicalization before matching the literal mountpoint.\n' >&2
    exit 1
fi

if ((detect_line >= health_line || health_line >= detach_line \
    || detach_line >= redetect_line || redetect_line >= inspect_line \
    || inspect_line >= unlink_line || unlink_line >= ensure_line \
    || ensure_line >= prepared_line || prepared_line >= mount_line \
    || mount_line >= mounted_health_line \
    || mounted_health_line >= restore_line)); then
    printf 'Gluster RRD mountpoint checks and repair must precede the mount operation.\n' >&2
    exit 1
fi

printf 'Gluster RRD mount guardrail test passed.\n'
