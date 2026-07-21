#!/usr/bin/env python3
"""Check static invariants that protect unattended HA operations."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, needle: str, description: str) -> list[str]:
    if needle in read(path):
        return []
    return [f"{description}: expected {needle!r} in {path}"]


def pinned_python_requirement(content: str, package: str) -> str | None:
    match = re.search(
        rf"^{re.escape(package)}==([^\s#]+)$",
        content,
        flags=re.MULTILINE,
    )
    return match.group(1) if match else None


def main() -> int:
    failures: list[str] = []
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
        'LIBRENMS_DAILY_HA_DRAIN_ENABLED="${HA_DRAIN_ENABLED}"',
        "Only the global-lock holder may drain itself for HA maintenance",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-daily-wrapper.sh.j2",
        'if [ "${GLOBAL_LOCK_ENABLED}" != "true" ]; then\n    activate_ha_drain',
        "Global maintenance contenders must not drain before acquiring the lock",
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
    if read("roles/librenms_app/tasks/main.yml").count('validate: "bash -n %s"') < 2:
        failures.append(
            "Deployment must validate rendered daily-maintenance and backup shell wrappers"
        )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_daily_service_timeout: 10800",
        "Daily service timeout must allow queued HA nodes to acquire the lock",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_startup_repair_restart_php_fpm_on_db_gone_away: false",
        "Transient database errors must not restart PHP-FPM by default",
    )
    failures += require(
        "roles/librenms_defaults/defaults/main.yml",
        "librenms_app_probe_fail_deployment: true",
        "Application health checks must fail deployment after recovery is exhausted",
    )
    failures += require(
        "roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2",
        "PHP-FPM recovery cooldown is active",
        "Optional PHP-FPM database recovery must be rate-limited",
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
        "Require a GlusterFS-backed HA maintenance lock",
        "Production readiness must verify the HA maintenance lock is shared",
    )
    failures += require(
        "roles/production_readiness/tasks/main.yml",
        "Require a GlusterFS-backed RRD directory on every HA web node",
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
        "haproxy:3.4.0-alpine3.23",
        "HAProxy integration must use a fixed official HAProxy image tag",
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
        "tests/integration/redis-sentinel/compose.yml",
        "redis:7.4.9-alpine",
        "The Redis Sentinel integration test must use a fixed official image tag",
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

    if "apt_repository:" in read("roles/common/tasks/main.yml"):
        failures.append("Ubuntu repository management must use deb822_repository")

    if "deb822_repository:" not in read("roles/common/tasks/main.yml"):
        failures.append("Ubuntu repository management must declare deb822_repository")

    role_files = (ROOT / "roles").rglob("*.yml")
    if any("community.mysql." in path.read_text(encoding="utf-8") for path in role_files):
        failures.append("MariaDB tasks must use ansible.mysql instead of deprecated community.mysql")

    collections_requirements = read("requirements.yml")
    for collection_name in ("ansible.posix", "community.general", "ansible.mysql"):
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
    if "runs-on: ubuntu-24.04" not in lint_workflow:
        failures.append("Lint workflow must pin its runner to ubuntu-24.04")
    if "timeout-minutes: 20" not in lint_workflow:
        failures.append("Lint workflow must bound execution time to 20 minutes")
    if "python -m pip install --requirement requirements-ci.txt" not in lint_workflow:
        failures.append("Lint workflow must install the pinned CI toolchain")
    if "python -m pip check" not in lint_workflow:
        failures.append("Lint workflow must verify installed Python dependencies")
    if "controller-image:" not in lint_workflow:
        failures.append("Lint workflow must build the Ansible controller image")
    if "docker compose run --rm --no-deps ansible make ci" not in lint_workflow:
        failures.append("Lint workflow must run quality gates inside the controller image")

    ci_requirements = read("requirements-ci.txt")
    ci_tool_versions: dict[str, str] = {}
    for package in ("ansible-core", "ansible-lint", "yamllint"):
        version = pinned_python_requirement(ci_requirements, package)
        if version is None:
            failures.append(f"CI toolchain must pin {package}")
        else:
            ci_tool_versions[package] = version

    dockerfile = read("Dockerfile")
    if "COPY requirements-ci.txt requirements.yml /tmp/" not in dockerfile:
        failures.append("Docker development image must include the pinned CI toolchain")
    if "--requirement /tmp/requirements-ci.txt" not in dockerfile:
        failures.append("Docker development image must install the pinned CI toolchain")
    if "&& python -m pip check" not in dockerfile:
        failures.append("Docker development image must verify installed Python dependencies")
    if "FROM python:3.12-slim@sha256:" not in dockerfile:
        failures.append("Docker development image must pin its Python base image by digest")

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
