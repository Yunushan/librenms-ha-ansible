#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULTS_FILE="$ROOT_DIR/roles/awx_bootstrap/defaults/main.yml"
TASKS_FILE="$ROOT_DIR/roles/awx_bootstrap/tasks/main.yml"
SCHEDULE_FILE="$ROOT_DIR/roles/awx_bootstrap/tasks/status_schedule.yml"

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Missing expected AWX status schedule guardrail in %s: %s\n' \
            "$file" "$expected" >&2
        exit 1
    fi
}

require_text "$DEFAULTS_FILE" "awx_bootstrap_status_schedule_enabled: true"
require_text "$DEFAULTS_FILE" "FREQ=MINUTELY;INTERVAL=10"
require_text "$TASKS_FILE" "Validate managed AWX strict-status schedule settings"
require_text "$TASKS_FILE" "Ensure managed AWX strict-status schedule"
require_text "$SCHEDULE_FILE" "librenms_status_alert_fail_on_degraded: true"
require_text "$SCHEDULE_FILE" "Create AWX strict-status schedule"
require_text "$SCHEDULE_FILE" "Update AWX strict-status schedule"

printf 'AWX strict-status schedule guardrail test passed.\n'
