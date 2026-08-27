#!/usr/bin/env python3
"""Check static invariants that protect unattended HA operations."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

LEGACY_INJECTED_FACTS = (
    "ansible_architecture",
    "ansible_date_time",
    "ansible_default_ipv4",
    "ansible_distribution",
    "ansible_distribution_major_version",
    "ansible_distribution_release",
    "ansible_distribution_version",
    "ansible_interfaces",
    "ansible_kernel",
    "ansible_memtotal_mb",
    "ansible_mounts",
    "ansible_os_family",
    "ansible_selinux",
    "ansible_service_mgr",
)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, needle: str, description: str) -> list[str]:
    if needle in read(path):
        return []
    return [f"{description}: expected {needle!r} in {path}"]


def pinned_python_requirement(content: str, package: str) -> str | None:
    match = re.search(
        rf"^{re.escape(package)}==([^\s#]+)(?:\s+\\)?$",
        content,
        flags=re.MULTILINE,
    )
    return match.group(1) if match else None


def main() -> int:
    failures: list[str] = []
    failures += require(
        "Makefile",
        "site-ask-become-pass:",
        "Interactive site convergence must remain available for password-based sudo",
    )
    failures += require(
        "Makefile",
        "playbooks/site.yml --ask-become-pass --timeout "
        "$(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS)",
        "Interactive site convergence must use the hardened become settings",
    )
    failures += require(
        "Makefile",
        "INTERACTIVE_BECOME_TIMEOUT ?= 120",
        "Interactive become must tolerate bounded sudo/PAM prompt delays",
    )
    failures += require(
        "Makefile",
        "INTERACTIVE_BECOME_FORKS ?= 1",
        "Interactive become must serialize hosts by default",
    )
    failures += require(
        "Makefile",
        "platform-bootstrap-ask-become-pass:",
        "Managed Python recovery must remain available with password-based sudo",
    )
    failures += require(
        "Makefile",
        "playbooks/platform-bootstrap.yml --ask-become-pass --timeout "
        "$(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS)",
        "Managed Python recovery must use the hardened become settings",
    )
    failures += require(
        "ansible.cfg",
        "inject_facts_as_vars = False",
        "Ansible must exercise the explicit ansible_facts namespace",
    )
    legacy_fact_pattern = re.compile(
        rf"\b(?:{'|'.join(map(re.escape, LEGACY_INJECTED_FACTS))})\b"
    )
    for source_root in ("inventories", "playbooks", "roles"):
        for path in (ROOT / source_root).rglob("*"):
            if path.suffix not in {".j2", ".yaml", ".yml"}:
                continue
            match = legacy_fact_pattern.search(path.read_text(encoding="utf-8"))
            if match:
                failures.append(
                    f"{path.relative_to(ROOT)} uses deprecated injected fact "
                    f"{match.group(0)!r}; use ansible_facts instead"
                )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_daily_global_lock_enabled",
        "HA daily maintenance must use a global lock",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        "GLOBAL_LOCK_HELPER",
        "Daily wrapper must call the global lock helper",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        "acquire_cluster_maintenance_lock",
        "HA maintenance must serialize the entire wrapper with a shared lock",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        "activate_ha_drain",
        "HA maintenance must drain the web node for the entire wrapper run",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        'LIBRENMS_DAILY_HA_DRAIN_ENABLED="false"',
        "The outer daily wrapper must retain the HA drain through post-update recovery",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        'acquire_cluster_maintenance_lock\ncluster_lock_rc=$?',
        "Daily maintenance must acquire or skip the shared lock before draining a node",
    )
    failures += require(
        "tests/unit/test-daily-maintenance-guardrails.sh",
        "Daily-maintenance drain guardrail test passed",
        "CI must test the daily maintenance drain ordering",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-daily-maintenance-guardrails",
        "CI must run the daily maintenance drain guardrail test",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        "cleanup_ha_drain",
        "HA maintenance must restore the web node only when the wrapper exits",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_daily_global_lock_backend",
        "HA maintenance must declare its lock backend",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-global-lock.php.j2",
        "GET_LOCK",
        "Global lock helper must acquire a database lock",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-global-lock.php.j2",
        "RELEASE_LOCK",
        "Global lock helper must release a database lock",
    )
    lock_helper = read("roles/librenms_app/templates/librenms-daily-global-lock.php.j2")
    if lock_helper.count("exit(") != 2:
        failures.append(
            "Global lock helper must exit only during preflight or after PHP finally cleanup"
        )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-global-lock.php.j2",
        "draining this web node before maintenance",
        "The global lock holder must drain its web node before HA maintenance",
    )
    failures += require(
        "roles/librenms_app/templates/nginx-librenms.conf.j2",
        "librenms_daily_ha_drain_path",
        "Nginx health checks must honor the HA daily drain marker",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily.service.j2",
        "ExecStopPost=/usr/bin/rm -f -- {{ librenms_daily_ha_drain_path }}",
        "The daily service must clean a stale HA drain marker after stopping",
    )
    failures += require(
        "roles/librenms_app/tasks/main.yml",
        'validate: "php -l %s"',
        "Deployment must validate the generated PHP lock helper",
    )
    if read("roles/librenms_app/tasks/main.yml").count('validate: "bash -n %s"') < 3:
        failures.append(
            "Deployment must validate rendered daily-maintenance, backup, and startup-repair shell wrappers"
        )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_daily_service_timeout: 10800",
        "Daily service timeout must allow queued HA nodes to acquire the lock",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_startup_repair_restart_php_fpm_on_db_gone_away: >-",
        "HA database errors must trigger guarded stale-worker recovery by default",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_startup_repair_reload_php_fpm_after_db_recovery: >-",
        "HA database recovery must recycle stale PHP-FPM database connections by default",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_startup_repair_db_readiness_marker:",
        "HA database recovery must retain readiness transition state",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_app_probe_fail_deployment: true",
        "Application health checks must fail deployment after recovery is exhausted",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2",
        "PHP-FPM recovery cooldown is active",
        "PHP-FPM database recovery must be rate-limited",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2",
        "recover_php_fpm_after_db_recovery()",
        "Startup repair must react to a database unready-to-ready transition",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2",
        'PHP-FPM recovery cooldown is active"\n    return 75',
        "A rate-limited PHP-FPM recovery must remain pending for a later retry",
    )
    if (
        read("roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2").count(
            "recover_php_fpm_after_db_recovery || true"
        )
        < 2
    ):
        failures.append(
            "Startup repair must sample database readiness before and after service recovery"
        )
    failures += require(
        "roles/mariadb/tasks/main.yml",
        "librenms_mariadb_upstream_repo_setup_checksum",
        "MariaDB repository setup must require a checksum",
    )
    failures += require(
        "roles/mariadb/tasks/main.yml",
        "checksum: \"{{ librenms_mariadb_upstream_repo_setup_checksum }}\"",
        "MariaDB repository download must verify its checksum",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_mariadb_upstream_galera_supported_series:",
        "MariaDB series capabilities must distinguish local and Galera support",
    )
    failures += require(
        "tests/unit/test-mariadb-series-guardrails.sh",
        "MariaDB series guardrail test passed.",
        "CI must test MariaDB series capability guardrails",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-mariadb-series-guardrails",
        "CI must run the MariaDB series guardrail test",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-backup.sh.j2",
        "copy_offsite()",
        "Backup wrapper must retain an offsite copy capability",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-backup.sh.j2",
        "flock -w \"${BACKUP_LOCK_TIMEOUT}\"",
        "Backup wrapper must wait safely for an in-progress local backup",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-backup.sh.j2",
        "offsite backup manifest could not be read after copy",
        "Backup wrapper must verify the copied offsite manifest",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-backup.sh.j2",
        "artifact_sha256()",
        "Managed backups must record cryptographic artifact checksums",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-backup.sh.j2",
        "rsync -a --checksum --dry-run",
        "Offsite backup copies must be compared by checksum after transfer",
    )
    failures += require(
        "roles/backup/tasks/main.yml",
        "checksum_sha256:",
        "Manual backup manifests must record artifact checksums",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "wsrep_local_state_comment",
        "Production readiness must verify Galera membership, not just service state",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_galera_auto_recover_unsafe_bootstrap: false",
        "Existing Galera clusters must not auto-bootstrap unsafely",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        'LIBRENMS_DAILY_HA_DRAIN_ENABLED="false"',
        "The outer daily wrapper must retain the HA drain through post-update recovery",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        "recover_web_health()",
        "Daily maintenance must verify and recover local web health before rejoining HA traffic",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-runtime-health.php.j2",
        "SELECT 1 AS ready",
        "HAProxy runtime health checks must verify a fresh LibreNMS database query",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-runtime-health.php.j2",
        "http_response_code(503)",
        "HAProxy runtime health checks must report database failures as unavailable",
    )
    failures += require(
        "roles/librenms_app/templates/nginx-librenms.conf.j2",
        "librenms_nginx_runtime_health_check_path",
        "Nginx must route the LibreNMS runtime database health probe",
    )
    failures += require(
        "roles/haproxy_keepalived/templates/haproxy.cfg.j2",
        "librenms_haproxy_web_runtime_check_enabled",
        "HAProxy must use the runtime database health probe when managed",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify database runtime health on every active LibreNMS web node",
        "Production readiness must prove database runtime health on every web node",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_require_recent_failover_evidence",
        "HA production readiness must require recent failover evidence by default",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_require_failover_evidence_integrity",
        "HA production readiness must require failover evidence integrity by default",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require the recent HA failover drill covers essential cases",
        "Production readiness must reject stale or incomplete failover evidence",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require HA failover drill evidence checksum matches",
        "Production readiness must verify retained failover evidence integrity",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "librenms_production_latest_failover_evidence.vip",
        "Production readiness must bind failover evidence to the current VIP",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "librenms_production_latest_failover_evidence.elapsed_seconds",
        "Production readiness must reject failover evidence without a recovery-time measurement",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require scheduled daily backup health",
        "Production readiness must verify the continuing daily backup schedule",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require disposable database restore verification within its objective",
        "Production readiness must enforce a measured database restore objective",
    )
    failures += require(
        "roles/ha_failover_test/tasks/post_recovery.yml",
        "'mode': librenms_mode",
        "Failover evidence must identify its HA mode",
    )
    failures += require(
        "roles/ha_failover_test/tasks/post_recovery.yml",
        "Require HA failover drill recovery within its objective",
        "Failover drills must enforce a configurable recovery-time objective",
    )
    production_readiness_playbook = read("playbooks/production-readiness.yml")
    if (
        production_readiness_playbook.index("- role: doctor")
        > production_readiness_playbook.index("- role: production_readiness")
    ):
        failures.append(
            "Production readiness evidence must run after the live Doctor network checks"
        )
    failures += require(
        "tests/unit/test-runtime-web-health-guardrails.sh",
        "Runtime web-health guardrail test passed",
        "CI must test runtime database health routing",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-runtime-web-health-guardrails",
        "CI must run the runtime web-health guardrail test",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_galera_recovery_tie_breaker: manual",
        "Galera recovery must not choose the first tied member by default",
    )
    failures += require(
        "roles/galera/tasks/main.yml",
        "Fail closed when existing Galera cluster needs manual recovery",
        "Existing Galera clusters must require guarded recovery after total outage",
    )
    failures += require(
        "tests/unit/test-galera-bootstrap-guardrails.sh",
        "Galera bootstrap guardrail test passed",
        "CI must test Galera bootstrap safety",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-galera-bootstrap-guardrails",
        "CI must run the Galera bootstrap safety test",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require active Galera HAProxy readiness agent sockets",
        "Production readiness must verify Galera-aware HAProxy backend health",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Prove fresh LibreNMS database connections through the HAProxy VIP",
        "Production readiness must prove fresh database connections through HAProxy",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require one LibreNMS revision across every application node",
        "Production readiness must prevent mixed application revisions",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require a shared-filesystem-backed HA maintenance lock",
        "Production readiness must verify the HA maintenance lock is shared",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_daily_canary_enabled",
        "HA daily maintenance must declare deterministic canary protection",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require a shared-filesystem-backed daily-update canary state",
        "Production readiness must verify the canary state is shared",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require a shared-filesystem-backed RRD directory on every HA web node",
        "Production readiness must verify every HA web node uses shared RRD storage",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require exactly one shared maintenance lock probe winner",
        "Production readiness must prove the shared maintenance lock excludes peers",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "SENTINEL get-master-addr-by-name",
        "Production readiness must verify Redis Sentinel master agreement",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "librenms:production-readiness",
        "Production readiness must verify a writable Redis cache master",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify LibreNMS application response through the VIP",
        "Production readiness must probe the application through the VIP",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify VIP TLS certificate with its configured SNI hostname",
        "Production readiness must verify a TLS-enabled VIP certificate",
    )
    failures += require(
        "playbooks/production-readiness.yml",
        "librenms_doctor_network_tcp_checks_enabled",
        "Production readiness must run the live TCP network matrix",
    )
    failures += require(
        "Makefile",
        "production-readiness:",
        "Production readiness must have a controller Make target",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Prove the scheduled backup also reaches the offsite target",
        "Production readiness must prove the required offsite backup copy",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify generated database backup gzip integrity",
        "Production readiness must verify generated database backup integrity",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require generated backup manifest SHA-256 checksums to match",
        "Production readiness must reject modified backup artifacts",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Import generated database backup into disposable target",
        "Production readiness must prove the generated database backup imports",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_write_evidence: true",
        "Production readiness must retain passing evidence by default",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_evidence_integrity_enabled: true",
        "Production readiness evidence must be integrity-protected by default",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_evidence_hmac_enabled",
        "Production readiness evidence must be authenticated by default",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Write successful production readiness evidence",
        "Successful readiness runs must retain controller-side evidence",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Write production readiness evidence checksum sidecar",
        "Successful readiness evidence must include a SHA-256 checksum sidecar",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify production readiness evidence checksum sidecar",
        "Production readiness must verify its generated evidence checksum",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require authenticated production readiness evidence sidecar matches",
        "Production readiness must verify its generated evidence HMAC",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Recalculate authenticated production readiness evidence digest after write",
        "Production readiness must recalculate the evidence HMAC after writing it",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "librenms_production_readiness_evidence_hmac_after_write.stdout",
        "Production readiness must compare its HMAC sidecar with a post-write digest",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify generated production readiness evidence with controller verifier",
        "Production readiness must verify evidence with the durable controller verifier",
    )
    failures += require(
        "roles/production_readiness/files/librenms-production-readiness-evidence-verify.py",
        "hmac.compare_digest",
        "Production readiness evidence verifier must use constant-time digest comparison",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Publish production readiness result for controller job records",
        "Production readiness must publish its result to controller job records",
    )
    failures += require(
        "tests/unit/test-production-readiness-evidence-guardrails.sh",
        "Production readiness evidence guardrail test passed",
        "CI must test production readiness evidence guardrails",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-production-readiness-evidence-guardrails",
        "CI must run the production readiness evidence guardrail test",
    )
    failures += require(
        "roles/awx_bootstrap/defaults/main.yml",
        "awx_bootstrap_status_schedule_enabled: true",
        "AWX bootstrap must manage recurring strict status checks by default",
    )
    failures += require(
        "tests/unit/test-awx-status-schedule-guardrails.sh",
        "AWX strict-status schedule guardrail test passed",
        "CI must test the managed AWX strict-status schedule",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-awx-status-schedule-guardrails",
        "CI must run the AWX strict-status schedule guardrail test",
    )
    failures += require(
        "roles/restore_test/defaults/main.yml",
        "librenms_restore_test_verify_database_import: true",
        "Restore tests must import database backups by default",
    )
    failures += require(
        "roles/restore_test/defaults/main.yml",
        "librenms_restore_test_select_latest: false",
        "Latest-backup restore selection must stay opt-in",
    )
    failures += require(
        "roles/restore_test/defaults/main.yml",
        "librenms_restore_test_require_checksums: true",
        "Restore tests must require checksum manifests by default",
    )
    failures += require(
        "roles/restore_test/tasks/main.yml",
        "Find managed latest-backup candidates",
        "Scheduled restore tests must discover managed backup candidates safely",
    )
    failures += require(
        "roles/restore_test/tasks/main.yml",
        "Import backup into disposable restore target",
        "Restore tests must import backups into a disposable database",
    )
    failures += require(
        "roles/restore_test/tasks/main.yml",
        "Remove disposable database restore target",
        "Restore tests must remove their disposable database target",
    )
    failures += require(
        "roles/restore_test/tasks/main.yml",
        "Require external database restore credentials",
        "External restore tests must require a dedicated credential",
    )
    failures += require(
        "roles/restore_test/tasks/main.yml",
        "Require matching SHA-256 checksums for required backup artifacts",
        "Restore tests must reject altered backup artifacts before import",
    )
    failures += require(
        "roles/ha_failover_test/tasks/main.yml",
        "Require every Redis Sentinel to agree on the new master",
        "Redis fault injection must verify Sentinel-wide master agreement",
    )
    failures += require(
        "roles/ha_failover_test/tasks/main.yml",
        "Require a fully synced Galera cluster before fault injection",
        "Galera fault injection must reject an unhealthy baseline",
    )
    failures += require(
        "roles/ha_failover_test/tasks/main.yml",
        "Verify HAProxy database frontend after Galera restore",
        "Galera fault injection must verify the database VIP after recovery",
    )
    failures += require(
        "roles/ha_failover_test/tasks/main.yml",
        "Verify the recovered LibreNMS HA stack",
        "Failover drills must run a final post-recovery gate",
    )
    failures += require(
        "roles/ha_failover_test/tasks/post_recovery.yml",
        "Run LibreNMS validation after all recoveries",
        "Failover drills must validate LibreNMS after restoring services",
    )
    failures += require(
        "roles/ha_failover_test/tasks/post_recovery.yml",
        "Write successful HA failover drill evidence",
        "Successful failover drills must retain controller-side evidence",
    )
    failures += require(
        "tests/unit/test-failover-recovery-guardrails.sh",
        "Failover recovery guardrail test passed",
        "CI must test failover recovery guardrails",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-failover-recovery-guardrails",
        "CI must run the failover recovery guardrail test",
    )
    failures += require(
        "playbooks/site.yml",
        "- name: Configure load balancer and VIP hosts\n  hosts: lb_nodes:!maintenance_nodes\n  become: true\n  gather_facts: true\n  serial: 1",
        "Site convergence must apply load-balancer changes one node at a time",
    )
    failures += require(
        "playbooks/syslog.yml",
        "- name: Refresh HAProxy database listener for syslog workers\n  hosts: lb_nodes:!maintenance_nodes\n  become: true\n  gather_facts: true\n  serial: 1",
        "Syslog deployment must apply load-balancer changes one node at a time",
    )
    failures += require(
        "tests/unit/test-load-balancer-rollout-guardrails.sh",
        "Load-balancer rollout guardrail test passed",
        "CI must test load-balancer rollout ordering",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-load-balancer-rollout-guardrails",
        "CI must run the load-balancer rollout guardrail test",
    )
    failures += require(
        "tests/unit/test-galera-readiness-agent.sh",
        "Galera readiness agent decision test passed",
        "CI must test Galera readiness-agent routing decisions",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-galera-readiness",
        "CI must run the Galera readiness-agent decision test",
    )
    failures += require(
        "tests/integration/haproxy-web/compose.yml",
        "nginx:1.31.3-alpine3.24@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752",
        "HAProxy integration web backends must use an immutable Nginx image digest",
    )
    failures += require(
        "tests/integration/haproxy-web/compose.yml",
        "haproxy:3.4.0-alpine3.23@sha256:5614ec450485ce1f9f8c25d231cf7fbab9326302a395f2355e05cbbc2dd7468b",
        "HAProxy integration must use an immutable HAProxy image digest",
    )
    failures += require(
        "tests/integration/haproxy-web/test.sh",
        "HAProxy web failover test passed",
        "HAProxy integration must assert continued service after a backend stops",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make integration-haproxy-web",
        "CI must run the HAProxy web failover integration test",
    )
    failures += require(
        "tests/integration/galera/compose.yml",
        "mariadb:11.4@sha256:a794d9eb009e20de605858a11f32f63b4075cbd197c650436f0e3b457e4caed7",
        "Galera integration must use an immutable official MariaDB 11.4 image digest",
    )
    failures += require(
        "tests/integration/galera/galera.cnf",
        "wsrep_sst_method=mariabackup",
        "Galera integration must use the image-provided MariaDB backup SST method",
    )
    failures += require(
        "tests/integration/galera/test.sh",
        "three synced Galera members",
        "Galera integration must prove initial three-member quorum",
    )
    failures += require(
        "tests/integration/galera/test.sh",
        "write replication after Galera primary-node loss",
        "Galera integration must prove write continuity after a node stops",
    )
    failures += require(
        "tests/integration/galera/test.sh",
        "post-failover write replication to the rejoined node",
        "Galera integration must prove rejoin replication",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make integration-galera",
        "CI must run the Galera quorum and rejoin integration test",
    )
    failures += require(
        "tests/integration/redis-sentinel/compose.yml",
        "redis:7.4.9-alpine@sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99",
        "The Redis Sentinel integration test must use an immutable Redis image digest",
    )
    failures += require(
        "tests/integration/redis-sentinel/test.sh",
        "all_sentinels_agree_on",
        "The Redis Sentinel integration test must require Sentinel consensus",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make integration-redis-sentinel",
        "CI must execute the Redis Sentinel failover integration test",
    )
    failures += require(
        "examples/docker-ha/mariadb-galera/compose.yml",
        "MARIADB_GALERA_IMAGE:?Set MARIADB_GALERA_IMAGE",
        "The Docker Galera example must require an explicit immutable image",
    )
    failures += require(
        "examples/docker-ha/mariadb-galera/.env.example",
        "REPLACE_WITH_APPROVED_IMAGE_DIGEST",
        "The Docker Galera example must document an immutable image digest",
    )
    failures += require(
        "tests/unit/test-docker-ha-galera-config.sh",
        "Docker Galera example configuration test passed",
        "The Docker Galera example must test its fail-closed image setting",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-docker-ha-galera-config",
        "CI must validate the Docker Galera example configuration",
    )
    failures += require(
        "roles/awx_bootstrap/defaults/main.yml",
        "awx_bootstrap_restore_test_schedule_enabled: false",
        "The AWX restore-test schedule must be opt-in",
    )
    failures += require(
        "roles/awx_bootstrap/tasks/restore_test_schedule.yml",
        "librenms_restore_test_select_latest: true",
        "The AWX restore-test schedule must select the latest managed backup",
    )
    failures += require(
        "roles/awx_bootstrap/defaults/main.yml",
        "awx_bootstrap_failover_drill_schedule_enabled: false",
        "The AWX failover-drill schedule must be opt-in",
    )
    failures += require(
        "roles/awx_bootstrap/tasks/failover_drill_schedule.yml",
        "librenms_failover_test_confirm: true",
        "The AWX failover-drill schedule must explicitly confirm disruption",
    )

    if "--skip-verify" in read("roles/mariadb/tasks/main.yml"):
        failures.append("MariaDB repository setup must not bypass verification")

    common_tasks = read("roles/common/tasks/main.yml")
    default_values = read("roles/librenms_defaults/defaults/main.yml")
    if "apt_repository:" in common_tasks:
        if (
            "ppa:ondrej/php" not in (common_tasks + default_values)
            or "librenms_ubuntu_php_repository_enabled" not in common_tasks
            or "librenms_ubuntu_php_repository_required" not in common_tasks
        ):
            failures.append(
                "Ubuntu PHP repository management must use the verified deb822 source and explicit repository-required guard"
            )

    if "deb822_repository:" not in common_tasks:
        failures.append("Ubuntu repository management must declare deb822_repository")

    role_files = (ROOT / "roles").rglob("*.yml")
    if any("community.mysql." in path.read_text(encoding="utf-8") for path in role_files):
        failures.append("MariaDB tasks must use ansible.mariadb instead of deprecated community.mysql")
    if any("ansible.mysql." in path.read_text(encoding="utf-8") for path in role_files):
        failures.append("MariaDB tasks must use ansible.mariadb instead of ansible.mysql")

    collections_requirements = read("requirements.yml")
    for collection_name in ("ansible.posix", "community.general", "ansible.mariadb"):
        if not re.search(
            rf"^  - name: {re.escape(collection_name)}\r?\n    version: \S+",
            collections_requirements,
            flags=re.MULTILINE,
        ):
            failures.append(f"requirements.yml must pin {collection_name}")

    lint_workflow = read(".github/workflows/lint.yml")
    for action_name in ("actions/checkout", "actions/setup-python"):
        if not re.search(
            rf"{re.escape(action_name)}@[0-9a-f]{{40}}(?:\s+#\s+v\S+)?",
            lint_workflow,
        ):
            failures.append(
                f"Lint workflow must pin {action_name} to an immutable commit"
            )
    if "permissions:\n  contents: read" not in lint_workflow:
        failures.append("Lint workflow must use a read-only GitHub token")
    if not re.search(
        r"(?ms)^concurrency:\s*\n\s+group:\s+\$\{\{ github\.workflow \}\}-\$\{\{ github\.ref \}\}\s*\n\s+cancel-in-progress:\s+true\s*$",
        lint_workflow,
    ):
        failures.append(
            "Lint workflow must cancel overlapping runs for the same ref"
        )
    if "runs-on: ubuntu-24.04" not in lint_workflow:
        failures.append("Lint workflow must pin its runner to ubuntu-24.04")
    if "timeout-minutes: 20" not in lint_workflow:
        failures.append("Lint workflow must bound execution time to 20 minutes")
    if "python -m pip install --require-hashes --requirement requirements-ci.txt" not in lint_workflow:
        failures.append("Lint workflow must install the hash-locked CI toolchain")
    if "python -m pip check" not in lint_workflow:
        failures.append("Lint workflow must verify installed Python dependencies")
    if "controller-image:" not in lint_workflow:
        failures.append("Lint workflow must build the Ansible controller image")
    if "docker compose run --rm --no-deps ansible make ci" not in lint_workflow:
        failures.append("Lint workflow must run quality gates inside the controller image")

    dependency_review_workflow = read(".github/workflows/dependency-review.yml")
    if "permissions:\n  contents: read" not in dependency_review_workflow:
        failures.append("Dependency review workflow must use a read-only GitHub token")
    if not re.search(
        r"(?ms)^concurrency:\s*\n\s+group:\s+\$\{\{ github\.workflow \}\}-\$\{\{ github\.ref \}\}\s*\n\s+cancel-in-progress:\s+true\s*$",
        dependency_review_workflow,
    ):
        failures.append(
            "Dependency review workflow must cancel overlapping runs for the same ref"
        )
    if "runs-on: ubuntu-24.04" not in dependency_review_workflow:
        failures.append("Dependency review workflow must pin its runner to ubuntu-24.04")
    if "timeout-minutes: 10" not in dependency_review_workflow:
        failures.append("Dependency review workflow must bound execution time to 10 minutes")
    if not re.search(
        r"actions/dependency-review-action@[0-9a-f]{40}(?:\s+#\s+v\S+)?",
        dependency_review_workflow,
    ):
        failures.append(
            "Dependency review workflow must pin its action to an immutable commit"
        )
    if "fail-on-severity: moderate" not in dependency_review_workflow:
        failures.append("Dependency review workflow must fail on moderate vulnerabilities")

    codeowners = read(".github/CODEOWNERS")
    if not re.search(
        r"(?m)^\s*\*\s+@[A-Za-z0-9-]+(?:\s+@[A-Za-z0-9-]+)*\s*$",
        codeowners,
    ):
        failures.append(
            "CODEOWNERS must assign an explicit owner for the complete repository"
        )

    github_governance_check = read("scripts/ci-github-governance-check.py")
    if "private-vulnerability-reporting" not in github_governance_check:
        failures.append(
            "GitHub governance check must verify private vulnerability reporting"
        )
    if "dependabot/alerts?state=open&per_page=1" not in github_governance_check:
        failures.append(
            "GitHub governance check must verify that no open Dependabot alerts remain"
        )
    if "code-scanning/default-setup" not in github_governance_check:
        failures.append(
            "GitHub governance check must verify CodeQL default setup"
        )
    if "protection/required_pull_request_reviews" not in github_governance_check:
        failures.append(
            "GitHub governance check must query the authoritative review-protection endpoint"
        )
    if (
        '["gh", "auth", "token", "--hostname", "github.com"]'
        not in github_governance_check
    ):
        failures.append(
            "GitHub governance check must request the explicit github.com auth token"
        )
    required_check_block = re.search(
        r"REQUIRED_CHECKS\s*=\s*\{(?P<body>.*?)\n\}",
        github_governance_check,
        flags=re.DOTALL,
    )
    expected_required_checks = (
        "python-314-runtime",
        "platform-packages (ubuntu-22.04)",
        "platform-packages (ubuntu-24.04)",
        "platform-packages (ubuntu-24.04-php-8.4)",
        "platform-packages (ubuntu-24.04-php-8.5)",
        "platform-packages (ubuntu-26.04)",
        "platform-packages (rocky-8)",
        "platform-packages (rocky-9)",
        "platform-packages (rocky-10)",
        "platform-packages (almalinux-8)",
        "platform-packages (almalinux-9)",
        "platform-packages (almalinux-10)",
    )
    if required_check_block is None:
        failures.append("GitHub governance check must declare its required checks")
    else:
        missing_required_checks = [
            check
            for check in expected_required_checks
            if f'"{check}"' not in required_check_block.group("body")
        ]
        if missing_required_checks:
            failures.append(
                "GitHub governance check must require every supported platform job: "
                + ", ".join(missing_required_checks)
            )

    workflow_root = ROOT / ".github" / "workflows"
    for workflow_path in sorted(workflow_root.glob("*.y*ml")):
        workflow_text = workflow_path.read_text(encoding="utf-8")
        if "pull_request_target:" in workflow_text:
            failures.append(
                f"{workflow_path.relative_to(ROOT)} must not execute untrusted pull requests with write-capable target context"
            )
        for line_number, line in enumerate(workflow_text.splitlines(), 1):
            action_match = re.match(r"^\s+uses:\s+\S+@([^ #]+)", line)
            if action_match and not re.fullmatch(r"[0-9a-f]{40}", action_match.group(1)):
                failures.append(
                    f"{workflow_path.relative_to(ROOT)}:{line_number} must pin GitHub actions to an immutable commit"
                )

    ci_requirements = read("requirements-ci.txt")
    ci_tool_versions: dict[str, str] = {}
    for package in ("ansible-core", "ansible-lint", "yamllint"):
        version = pinned_python_requirement(ci_requirements, package)
        if version is None:
            failures.append(f"CI toolchain must pin {package}")
        else:
            ci_tool_versions[package] = version

    dockerfile = read("Dockerfile")
    if "COPY requirements-ci.in requirements-ci.txt requirements.yml /tmp/" not in dockerfile:
        failures.append("Docker development image must include the CI lock source and lock file")
    if "--require-hashes --requirement /tmp/requirements-ci.txt" not in dockerfile:
        failures.append("Docker development image must install the hash-locked CI toolchain")
    if "&& python -m pip check" not in dockerfile:
        failures.append("Docker development image must verify installed Python dependencies")
    if not re.search(r"(?m)^FROM python:3\.12-slim@sha256:[0-9a-f]{64}\r?$", dockerfile):
        failures.append(
            "Docker development image must use the approved Python 3.12 slim base image with a SHA-256 digest"
        )

    pre_commit_config = read(".pre-commit-config.yaml")
    for package in ("ansible-lint", "yamllint"):
        version = ci_tool_versions.get(package)
        if version and f"rev: v{version}" not in pre_commit_config:
            failures.append(
                f"Pre-commit {package} hook must match requirements-ci.txt {version}"
            )

    app_tasks = read("roles/librenms_app/tasks/main.yml")
    php_fpm_recovery = app_tasks[
        app_tasks.index("- name: Recover PHP-FPM endpoint before final LibreNMS web probe")
        : app_tasks.index("- name: Verify LibreNMS application endpoint responds on each web node")
    ]
    if "Require the PHP-FPM ping endpoint before continuing" not in php_fpm_recovery:
        failures.append("PHP-FPM recovery must explicitly assert the initial ping result")
    if "Require the PHP-FPM ping endpoint after service recovery" not in php_fpm_recovery:
        failures.append("PHP-FPM recovery must explicitly assert its retry result")
    if "ignore_errors: true" in php_fpm_recovery:
        failures.append("PHP-FPM recovery must not suppress an exhausted recovery failure")

    daily_wrapper = read("roles/librenms_app/templates/librenms-daily-wrapper.sh.j2")
    if "librenms_nginx_runtime_health_check_path if daily_runtime_health_enabled" not in daily_wrapper:
        failures.append(
            "Daily maintenance must use the PHP database runtime health probe in HA mode"
        )

    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_manage_host_firewall: false",
        "Host firewall enforcement must stay opt-in until CIDRs are reviewed",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_production_profile: false",
        "Production hardening must be an explicit inventory declaration",
    )
    failures += require(
        "roles/host_firewall/tasks/ufw.yml",
        "Allow management SSH before enabling UFW",
        "Host firewall policy must preserve management SSH before enabling UFW",
    )
    failures += require(
        "roles/host_firewall/tasks/ufw.yml",
        "Set UFW default incoming policy to deny",
        "Host firewall policy must deny unapproved inbound traffic",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require active UFW when the managed host-firewall policy is enabled",
        "Production readiness must verify an enabled host firewall remains active",
    )
    failures += require(
        "roles/host_firewall/tasks/firewalld.yml",
        "Allow management SSH before restricting firewalld",
        "firewalld policy must preserve management SSH before restricting ingress",
    )
    failures += require(
        "roles/host_firewall/tasks/firewalld.yml",
        "Set firewalld zone target to DROP after allow rules exist",
        "firewalld policy must deny unapproved inbound traffic",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require active firewalld when the managed host-firewall policy is enabled",
        "Production readiness must verify managed firewalld remains active",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "librenms_production_profile | bool and librenms_mode == 'ha'",
        "A declared HA production profile must require hardened controls",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "or librenms_haproxy_tls_enabled | bool",
        "A declared HA production profile must require VIP TLS",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_require_status_alert_routing",
        "HA production readiness must require configured status alert routing",
    )
    failures += require(
        "roles/production_readiness/defaults/main.yml",
        "librenms_production_readiness_require_encrypted_vault",
        "HA production readiness must require a verified secret source",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require an encrypted Ansible Vault secret file for production",
        "Production readiness must verify the configured Ansible Vault file",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Verify external production secret provider access",
        "External secret mode must verify provider access without exposing values",
    )
    failures += require(
        "scripts/ci-python-smoke.py",
        "scripts/ci-secret-scan.py",
        "CI must scan source files for obvious committed secrets",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "librenms_status_alert_webhook_url | default('')",
        "Production readiness must require certificate-validated HTTPS alert routing",
    )
    failures += require(
        "tests/unit/test-host-firewall-guardrails.sh",
        "Host-firewall guardrail test passed",
        "CI must test host-firewall safety ordering",
    )
    failures += require(
        ".github/workflows/lint.yml",
        "make test-host-firewall-guardrails",
        "CI must run host-firewall guardrail tests",
    )

    web_probe_recovery = app_tasks[
        app_tasks.index("- name: Verify LibreNMS application endpoint responds on each web node")
        : app_tasks.index("- name: Reconcile final LibreNMS dispatcher validation state")
    ]
    if "librenms_web_probe_retry.rc" in web_probe_recovery:
        failures.append("Web probe recovery diagnostics must test HTTP status, not uri rc")

    if failures:
        print("Production safety checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Production safety checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
