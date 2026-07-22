#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"
TASKS_FILE="$ROOT_DIR/roles/host_firewall/tasks/main.yml"
SITE_FILE="$ROOT_DIR/playbooks/site.yml"
FIREWALL_FILE="$ROOT_DIR/playbooks/firewall.yml"

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Missing expected host-firewall guardrail in %s: %s\n' \
            "$file" "$expected" >&2
        exit 1
    fi
}

require_text "$DEFAULTS_FILE" "librenms_manage_host_firewall: false"
require_text "$DEFAULTS_FILE" "librenms_host_firewall_management_sources: []"
require_text "$DEFAULTS_FILE" "librenms_host_firewall_cluster_sources: []"
require_text "$DEFAULTS_FILE" "librenms_syslog_manage_firewall: >-"
require_text "$DEFAULTS_FILE" "librenms_gluster_manage_firewall: >-"
require_text "$TASKS_FILE" "Validate explicit UFW host-firewall policy"
require_text "$TASKS_FILE" "Allow management SSH before enabling UFW"
require_text "$TASKS_FILE" "Allow trusted cluster CIDRs before enabling UFW"
require_text "$TASKS_FILE" "Set UFW default incoming policy to deny"
require_text "$TASKS_FILE" "Enable source-restricted UFW policy"
require_text "$FIREWALL_FILE" "serial: 1"
require_text "$SITE_FILE" "Enforce explicitly configured host firewall policy"

ssh_line="$(grep -nF 'Allow management SSH before enabling UFW' "$TASKS_FILE" | cut -d: -f1)"
deny_line="$(grep -nF 'Set UFW default incoming policy to deny' "$TASKS_FILE" | cut -d: -f1)"
enable_line="$(grep -nF 'Enable source-restricted UFW policy' "$TASKS_FILE" | cut -d: -f1)"

if [ "$ssh_line" -ge "$deny_line" ] || [ "$deny_line" -ge "$enable_line" ]; then
    printf 'UFW rule ordering must preserve SSH before deny/enable.\n' >&2
    exit 1
fi

printf 'Host-firewall guardrail test passed.\n'
