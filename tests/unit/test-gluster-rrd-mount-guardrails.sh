#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKS_FILE="$ROOT_DIR/roles/glusterfs_rrd/tasks/main.yml"

require_text() {
    local expected="$1"

    if ! grep -Fq -- "$expected" "$TASKS_FILE"; then
        printf 'Missing expected Gluster RRD mount guardrail: %s\n' "$expected" >&2
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

detect_line="$(grep -nF 'Detect active Gluster-backed RRD mount' "$TASKS_FILE" | cut -d: -f1)"
inspect_line="$(grep -nF 'Inspect unmounted RRD mountpoint path' "$TASKS_FILE" | cut -d: -f1)"
unlink_line="$(grep -nF 'Remove legacy RRD mountpoint symlink' "$TASKS_FILE" | cut -d: -f1)"
ensure_line="$(grep -nF 'Ensure unmounted RRD mountpoint exists' "$TASKS_FILE" | cut -d: -f1)"
mount_line="$(grep -nF 'Mount GlusterFS volume on LibreNMS nodes' "$TASKS_FILE" | cut -d: -f1)"
nocanonicalize_line="$(grep -nF -- '--nocanonicalize' "$TASKS_FILE" | cut -d: -f1)"
mountpoint_option_line="$(grep -nF -- '--mountpoint' "$TASKS_FILE" | cut -d: -f1)"

if ((nocanonicalize_line >= mountpoint_option_line)); then
    printf 'findmnt must disable canonicalization before matching the literal mountpoint.\n' >&2
    exit 1
fi

if ((detect_line >= inspect_line || inspect_line >= unlink_line \
    || unlink_line >= ensure_line || ensure_line >= mount_line)); then
    printf 'Gluster RRD mountpoint checks and repair must precede the mount operation.\n' >&2
    exit 1
fi

printf 'Gluster RRD mount guardrail test passed.\n'
