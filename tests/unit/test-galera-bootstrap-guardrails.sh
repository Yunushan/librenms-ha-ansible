#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASKS_FILE="$ROOT_DIR/roles/galera/tasks/main.yml"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Missing expected Galera bootstrap guardrail in %s: %s\n' \
            "$file" "$expected" >&2
        exit 1
    fi
}

require_text "$DEFAULTS_FILE" "librenms_galera_auto_recover_unsafe_bootstrap: false"
require_text "$DEFAULTS_FILE" "librenms_galera_recovery_tie_breaker: manual"
require_text "$TASKS_FILE" "Determine whether Galera requires its initial bootstrap"
require_text "$TASKS_FILE" "Fail closed when existing Galera cluster needs manual recovery"
require_text "$TASKS_FILE" "librenms_galera_marker.stat.exists | default(false) | bool"
require_text "$TASKS_FILE" "if librenms_galera_initial_bootstrap_required | bool"

printf 'Galera bootstrap guardrail test passed.\n'
