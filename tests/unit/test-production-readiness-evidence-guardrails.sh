#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TASKS_FILE="$ROOT_DIR/roles/production_readiness/tasks/main.yml"
DEFAULTS_FILE="$ROOT_DIR/roles/production_readiness/defaults/main.yml"
PLAYBOOK_FILE="$ROOT_DIR/playbooks/production-readiness.yml"
GLOBAL_DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Missing expected production readiness evidence guardrail in %s: %s\n' \
            "$file" "$expected" >&2
        exit 1
    fi
}

require_text "$DEFAULTS_FILE" "librenms_production_readiness_write_evidence: true"
require_text "$GLOBAL_DEFAULTS_FILE" "librenms_production_profile: false"
require_text "$DEFAULTS_FILE" "librenms_production_profile | bool or librenms_manage_host_firewall | bool"
require_text "$DEFAULTS_FILE" "librenms_production_profile | bool and librenms_mode == 'ha'"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_evidence_retention_days: 365"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_evidence_integrity_enabled: true"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_evidence_hmac_enabled"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_evidence_verifier_path"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_require_recent_failover_evidence"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_failover_evidence_max_age_days: 30"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_require_failover_evidence_integrity"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_max_failover_recovery_seconds"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_max_database_restore_seconds: 1800"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_require_scheduled_daily_backup"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_require_status_alert_routing"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_require_encrypted_vault"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_secret_source: ansible_vault"
require_text "$DEFAULTS_FILE" "librenms_production_readiness_external_secret_validation_command: []"
require_text "$TASKS_FILE" "Create controller-side production readiness evidence directory"
require_text "$TASKS_FILE" "Find expired production readiness evidence records"
require_text "$TASKS_FILE" "Write successful production readiness evidence"
require_text "$TASKS_FILE" "Calculate generated production readiness evidence SHA-256 checksum"
require_text "$TASKS_FILE" "Write production readiness evidence checksum sidecar"
require_text "$TASKS_FILE" "Verify production readiness evidence checksum sidecar"
require_text "$TASKS_FILE" "production-readiness-*.json.sha256"
require_text "$TASKS_FILE" "Calculate authenticated production readiness evidence digest"
require_text "$TASKS_FILE" "Write authenticated production readiness evidence sidecar"
require_text "$TASKS_FILE" "Recalculate authenticated production readiness evidence digest after write"
require_text "$TASKS_FILE" "Require authenticated production readiness evidence sidecar matches"
require_text "$TASKS_FILE" "librenms_production_readiness_evidence_hmac_after_write.stdout"
require_text "$TASKS_FILE" "Install controller-side production readiness evidence verifier"
require_text "$TASKS_FILE" "Verify generated production readiness evidence with controller verifier"
require_text "$TASKS_FILE" "production-readiness-*.json.hmac"
require_text "$TASKS_FILE" "Publish production readiness result for controller job records"
require_text "$TASKS_FILE" "Find recent successful HA failover drill evidence"
require_text "$TASKS_FILE" "Require HA failover drill evidence checksum"
require_text "$TASKS_FILE" "Require HA failover drill evidence checksum matches"
require_text "$TASKS_FILE" "Require the recent HA failover drill covers essential cases"
require_text "$TASKS_FILE" "librenms_production_latest_failover_evidence.mode"
require_text "$TASKS_FILE" "librenms_production_latest_failover_evidence.vip"
require_text "$TASKS_FILE" "librenms_production_latest_failover_evidence.elapsed_seconds"
require_text "$TASKS_FILE" "failover_recovery_objective_seconds"
require_text "$TASKS_FILE" "Inspect scheduled daily backup timer health"
require_text "$TASKS_FILE" "Require scheduled daily backup health"
require_text "$TASKS_FILE" "Require disposable database restore verification within its objective"
require_text "$TASKS_FILE" "database_restore_elapsed_seconds"
require_text "$TASKS_FILE" "librenms_status_alert_webhook_url | default('')"
require_text "$TASKS_FILE" "librenms_status_alert_webhook_validate_certs | default(true)"
require_text "$TASKS_FILE" "Require a declared production secret source"
require_text "$TASKS_FILE" "librenms_production_profile | bool and librenms_mode == 'ha'"
require_text "$TASKS_FILE" "librenms_host_firewall_management_sources | length"
require_text "$TASKS_FILE" "librenms_host_firewall_cluster_sources | length"
require_text "$TASKS_FILE" "or librenms_haproxy_tls_enabled | bool"
require_text "$TASKS_FILE" "Verify external production secret provider access"
require_text "$TASKS_FILE" "expand_argument_vars: false"
require_text "$TASKS_FILE" "Require an encrypted Ansible Vault secret file for production"
require_text "$TASKS_FILE" ".startswith('\$ANSIBLE_VAULT;')"

doctor_offset="$(grep -nF -- "- role: doctor" "$PLAYBOOK_FILE" | head -n 1 | cut -d: -f1)"
readiness_offset="$(grep -nF -- "- role: production_readiness" "$PLAYBOOK_FILE" | head -n 1 | cut -d: -f1)"
[ -n "$doctor_offset" ] && [ -n "$readiness_offset" ] && [ "$doctor_offset" -lt "$readiness_offset" ] || {
    printf 'Production readiness evidence must run after the live Doctor network checks.\n' >&2
    exit 1
}

printf 'Production readiness evidence guardrail test passed.\n'
