#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKS_FILE="${ROOT_DIR}/roles/ha_failover_test/tasks/main.yml"
RECOVERY_FILE="${ROOT_DIR}/roles/ha_failover_test/tasks/post_recovery.yml"
DEFAULTS_FILE="${ROOT_DIR}/roles/ha_failover_test/defaults/main.yml"

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "${expected}" "${file}"; then
        printf 'Missing expected failover recovery guardrail in %s: %s\n' \
            "${file}" "${expected}" >&2
        exit 1
    fi
}

require_text "${TASKS_FILE}" "Verify the recovered LibreNMS HA stack"
require_text "${RECOVERY_FILE}" "Verify the VIP application endpoint after all recoveries"
require_text "${RECOVERY_FILE}" "Run LibreNMS validation after all recoveries"
require_text "${RECOVERY_FILE}" "Require LibreNMS dependencies after all recoveries"
require_text "${RECOVERY_FILE}" "Require HA failover drill recovery within its objective"
require_text "${RECOVERY_FILE}" "Write successful HA failover drill evidence"
require_text "${RECOVERY_FILE}" "Write HA failover drill evidence checksum"
require_text "${RECOVERY_FILE}" "Publish HA failover drill result for controller job records"
require_text "${RECOVERY_FILE}" "'mode': librenms_mode"
require_text "${RECOVERY_FILE}" "'vip': librenms_vip_ip"
require_text "${DEFAULTS_FILE}" "librenms_failover_test_post_recovery_validate: true"
require_text "${DEFAULTS_FILE}" "librenms_failover_test_write_evidence: true"
require_text "${DEFAULTS_FILE}" "librenms_failover_test_evidence_integrity_enabled: true"
require_text "${DEFAULTS_FILE}" "librenms_failover_test_max_recovery_seconds: 900"

printf 'Failover recovery guardrail test passed.\n'
