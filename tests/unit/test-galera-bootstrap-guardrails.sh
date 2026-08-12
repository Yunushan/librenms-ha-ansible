#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASKS_FILE="$ROOT_DIR/roles/galera/tasks/main.yml"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"
RECOVERY_TASKS_FILE="$ROOT_DIR/roles/galera_recover/tasks/main.yml"

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
require_text "$TASKS_FILE" "Fail closed when Galera bootstrap host is not selected"
require_text "$TASKS_FILE" "librenms_galera_marker.stat.exists | default(false) | bool"
require_text "$TASKS_FILE" "librenms_galera_existing_database_data"
require_text "$TASKS_FILE" "librenms_mariadb_datadir | default('/var/lib/mysql')"
require_text "$TASKS_FILE" "not librenms_galera_initial_bootstrap_required | bool"
require_text "$TASKS_FILE" "if librenms_galera_initial_bootstrap_required | bool"
require_text "$TASKS_FILE" "| default('', true)"
require_text "$TASKS_FILE" "librenms_galera_bootstrap_selected_from_recovery | default(false, true) | bool"
require_text "$TASKS_FILE" "librenms_galera_bootstrap_safety_verified"
require_text "$TASKS_FILE" "Fail closed when Galera bootstrap safety is not proven"
require_text "$TASKS_FILE" "librenms_galera_bootstrap_effective_host in (librenms_active_db_nodes | default([]))"
require_text "$TASKS_FILE" "librenms_galera_bootstrap_effective_host not in ("
require_text "$TASKS_FILE" 'delegate_to: "{{ librenms_galera_bootstrap_effective_host | default(inventory_hostname, true) }}"'
require_text "$TASKS_FILE" "librenms_galera_local_service_expected"
require_text "$TASKS_FILE" "librenms_galera_cluster_has_live_member | bool"
require_text "$TASKS_FILE" "librenms_galera_bootstrap_effective_host in (librenms_active_db_nodes | default([]))"
require_text "$RECOVERY_TASKS_FILE" "End Galera recovery after read-only evidence collection"
require_text "$RECOVERY_TASKS_FILE" "End Galera recovery after confirmed position collection"
require_text "$RECOVERY_TASKS_FILE" "librenms_galera_recover_bootstrap_host | default('', true) | trim | length == 0"

require_safe_delegated_result_loop() {
    local file="$1"
    local task_name="$2"
    local task_block

    task_block="$(awk -v target="- name: $task_name" '
        $0 == target { capture=1 }
        capture && /^- name:/ && $0 != target { exit }
        capture { print }
    ' "$file")"

    if [ -z "$task_block" ]; then
        printf 'Missing delegated Galera task in %s: %s\n' "$file" "$task_name" >&2
        exit 1
    fi

    if ! grep -Fq -- "selectattr('item', 'defined')" <<<"$task_block" ||
        ! grep -Fq -- "selectattr('rc', 'defined')" <<<"$task_block"; then
        printf 'Delegated Galera task must reject incomplete loop results in %s: %s\n' \
            "$file" "$task_name" >&2
        exit 1
    fi
}

require_safe_delegated_result_loop \
    "$TASKS_FILE" \
    "Force kill stale MariaDB processes before recovery probes"
require_safe_delegated_result_loop \
    "$TASKS_FILE" \
    "Reset MariaDB unit state after forced recovery stop # noqa: command-instead-of-module"
require_safe_delegated_result_loop \
    "$TASKS_FILE" \
    "Force kill stale MariaDB processes before Galera bootstrap"
require_safe_delegated_result_loop \
    "$TASKS_FILE" \
    "Reset MariaDB unit state after force kill"
require_safe_delegated_result_loop \
    "$RECOVERY_TASKS_FILE" \
    "Force kill stale MariaDB processes before recovery probes"
require_safe_delegated_result_loop \
    "$RECOVERY_TASKS_FILE" \
    "Reset MariaDB unit state after forced recovery stop"

evidence_end_line="$(grep -nF -- '- name: End Galera recovery after read-only evidence collection' "$RECOVERY_TASKS_FILE" | cut -d: -f1)"
recovery_assert_line="$(grep -nF -- '- name: Require explicit recovery confirmation and selected host' "$RECOVERY_TASKS_FILE" | cut -d: -f1)"

if [ -z "$evidence_end_line" ] || [ -z "$recovery_assert_line" ] || [ "$evidence_end_line" -ge "$recovery_assert_line" ]; then
    printf 'Read-only Galera recovery must end before the bootstrap assertion.\n' >&2
    exit 1
fi

if grep -Fq -- 'delegate_to: "{{ librenms_galera_bootstrap_effective_host }}"' "$TASKS_FILE"; then
    printf 'Galera bootstrap delegation must always have a non-empty fallback host.\n' >&2
    exit 1
fi

recovery_block="$(awk '
    /- name: Recover Galera positions when no node is marked safe to bootstrap/ { capture=1 }
    capture { print }
    capture && /- name:/ && !/- name: Recover Galera positions when no node is marked safe to bootstrap/ && seen { exit }
    capture && /register: librenms_galera_recovered_state/ { seen=1 }
' "$TASKS_FILE")"

if ! grep -Fq -- 'inventory_hostname == (librenms_active_db_nodes | first)' <<<"$recovery_block"; then
    printf 'Galera recovery probes must run only on the active DB coordinator.\n' >&2
    exit 1
fi

if ! grep -Fq -- 'recovery_output="$(galera_recovery 2>&1)"' "$TASKS_FILE"; then
    printf 'Galera recovery diagnostics must preserve galera_recovery output.\n' >&2
    exit 1
fi

printf 'Galera bootstrap guardrail test passed.\n'
