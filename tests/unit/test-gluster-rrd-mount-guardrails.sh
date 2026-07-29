#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKS_FILE="$ROOT_DIR/roles/glusterfs_rrd/tasks/main.yml"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"
RUNTIME_WAIT_TEMPLATE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-runtime-wait.sh.j2"
STARTUP_REPAIR_TEMPLATE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"

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
    'umount --lazy -- "${RRD_PATH}"'
require_file_text "$STARTUP_REPAIR_TEMPLATE" \
    'systemctl stop "${RRDCACHED_SERVICE}"'
require_file_text "$STARTUP_REPAIR_TEMPLATE" \
    'systemctl start "${RRDCACHED_SERVICE}"'
require_file_text "$RUNTIME_WAIT_TEMPLATE" "--nocanonicalize"
require_file_text "$RUNTIME_WAIT_TEMPLATE" \
    'stat --dereference --format=%F'

startup_health_line="$(grep -nF 'rrd_path_accessible && return 0' "$STARTUP_REPAIR_TEMPLATE" | head -n 1 | cut -d: -f1)"
startup_enable_line="$(grep -nF 'GLUSTER_STALE_MOUNT_RECOVERY' "$STARTUP_REPAIR_TEMPLATE" | tail -n 1 | cut -d: -f1)"
startup_stop_line="$(grep -nF 'systemctl stop "${RRDCACHED_SERVICE}"' "$STARTUP_REPAIR_TEMPLATE" | cut -d: -f1)"
startup_unmount_line="$(grep -nF 'umount --lazy -- "${RRD_PATH}"' "$STARTUP_REPAIR_TEMPLATE" | cut -d: -f1)"
startup_mount_line="$(grep -nF 'mount "${RRD_PATH}"' "$STARTUP_REPAIR_TEMPLATE" | head -n 1 | cut -d: -f1)"
startup_start_line="$(grep -nF 'systemctl start "${RRDCACHED_SERVICE}"' "$STARTUP_REPAIR_TEMPLATE" | cut -d: -f1)"

if ((startup_health_line >= startup_enable_line \
    || startup_enable_line >= startup_stop_line \
    || startup_stop_line >= startup_unmount_line \
    || startup_unmount_line >= startup_mount_line \
    || startup_mount_line >= startup_start_line)); then
    printf 'Automatic stale-mount recovery must verify, drain, detach, remount, then restore RRDCacheD.\n' >&2
    exit 1
fi

detect_line="$(grep -nF 'Detect active Gluster-backed RRD mount' "$TASKS_FILE" | cut -d: -f1)"
health_line="$(grep -nF 'Probe active Gluster-backed RRD mount accessibility' "$TASKS_FILE" | cut -d: -f1)"
detach_line="$(grep -nF 'Lazily detach stale Gluster-backed RRD client mount' "$TASKS_FILE" | cut -d: -f1)"
redetect_line="$(grep -nF 'Re-detect Gluster-backed RRD mount after stale mount recovery' "$TASKS_FILE" | cut -d: -f1)"
inspect_line="$(grep -nF 'Inspect unmounted RRD mountpoint path' "$TASKS_FILE" | cut -d: -f1)"
unlink_line="$(grep -nF 'Remove legacy RRD mountpoint symlink' "$TASKS_FILE" | cut -d: -f1)"
ensure_line="$(grep -nF 'Ensure unmounted RRD mountpoint exists' "$TASKS_FILE" | cut -d: -f1)"
prepared_line="$(grep -nF 'Verify prepared unmounted RRD mountpoint' "$TASKS_FILE" | cut -d: -f1)"
mount_line="$(grep -nF 'Mount GlusterFS volume on LibreNMS nodes' "$TASKS_FILE" | cut -d: -f1)"
mounted_health_line="$(grep -nF 'Verify mounted Gluster-backed RRD path is accessible' "$TASKS_FILE" | cut -d: -f1)"
restore_line="$(grep -nF 'Restore RRDCacheD after stale Gluster RRD mount recovery' "$TASKS_FILE" | cut -d: -f1)"
nocanonicalize_line="$(grep -nF -- '--nocanonicalize' "$TASKS_FILE" | head -n 1 | cut -d: -f1)"
mountpoint_option_line="$(grep -nF -- '--mountpoint' "$TASKS_FILE" | head -n 1 | cut -d: -f1)"

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
