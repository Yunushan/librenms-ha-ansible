#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly TASKS_FILE="${ROOT_DIR}/roles/mariadb/tasks/main.yml"
readonly REPO_TASKS_FILE="${ROOT_DIR}/roles/common/tasks/mariadb_repos.yml"
readonly GALERA_TEMPLATE="${ROOT_DIR}/roles/galera/templates/galera.cnf.j2"
readonly GALERA_TASKS_FILE="${ROOT_DIR}/roles/galera/tasks/main.yml"
readonly MAINTENANCE_DEFAULTS_FILE="${ROOT_DIR}/roles/maintenance/defaults/main.yml"
readonly MAINTENANCE_EXIT_FILE="${ROOT_DIR}/roles/maintenance/tasks/exit.yml"
readonly MAINTENANCE_GALERA_REJOIN_FILE="${ROOT_DIR}/roles/maintenance/tasks/galera_rejoin.yml"
readonly README_FILE="${ROOT_DIR}/README.md"
readonly OPERATIONS_FILE="${ROOT_DIR}/docs/operations.md"
readonly SUPPORT_MATRIX_FILE="${ROOT_DIR}/docs/support-matrix.md"
readonly UPGRADE_RUNBOOK_FILE="${ROOT_DIR}/docs/mariadb-10.11-to-12.3.md"

fail() {
    printf 'MariaDB series guardrail test failed: %s\n' "$1" >&2
    exit 1
}

contains() {
    local file="$1"
    local text="$2"
    grep -Fq -- "${text}" "${file}" ||
        fail "${file} does not contain: ${text}"
}

does_not_contain() {
    local file="$1"
    local text="$2"
    if grep -Fq -- "${text}" "${file}"; then
        fail "${file} still contains: ${text}"
    fi
}

main() {
    contains "${DEFAULTS_FILE}" '- "11.4"'
    contains "${DEFAULTS_FILE}" '- "11.8"'
    contains "${DEFAULTS_FILE}" '- "12.3"'
    contains "${DEFAULTS_FILE}" 'librenms_mariadb_upstream_galera_supported_series:'
    contains "${DEFAULTS_FILE}" 'librenms_mariadb_12_3_galera_min_provider_version: "26.4.26"'
    contains "${DEFAULTS_FILE}" 'librenms_galera_gcache_size: 2G'
    contains "${GALERA_TEMPLATE}" 'gcache.recover=yes;gcache.size={{ librenms_galera_gcache_size }}'
    contains "${GALERA_TASKS_FILE}" "'wsrep_cluster_status','wsrep_ready','wsrep_local_state_comment'"
    contains "${TASKS_FILE}" 'librenms_mariadb_upstream_galera_supported_series'
    contains "${TASKS_FILE}" 'Enforce MariaDB 12.3 Galera provider package contract'
    contains "${TASKS_FILE}" 'librenms_mariadb_12_3_galera_min_provider_version'
    contains "${DEFAULTS_FILE}" 'librenms_ubuntu_mariadb_expected_series:'
    contains "${TASKS_FILE}" 'Enforce the supported Ubuntu distro MariaDB server series'
    contains "${REPO_TASKS_FILE}" '--mariadb-server-version=mariadb-{{ librenms_mariadb_upstream_series_effective }}'
    contains "${REPO_TASKS_FILE}" 'checksum: "{{ librenms_mariadb_upstream_repo_setup_checksum }}"'
    does_not_contain "${TASKS_FILE}" 'librenms_mariadb_allow_experimental_series'
    contains "${README_FILE}" 'Community repository support is available for explicit `11.4`, `11.8`, and'
    contains "${OPERATIONS_FILE}" 'Rolling Galera upgrades must visit 11.4, then 11.8, then 12.3'
    contains "${SUPPORT_MATRIX_FILE}" '| 12.3 | Supported after Stable/GA verification | Conditional on Debian-family hosts with separate `galera-4` >= 26.4.26'
    contains "${UPGRADE_RUNBOOK_FILE}" 'verify that the exact package candidate'
    contains "${UPGRADE_RUNBOOK_FILE}" 'is listed as Stable/GA'
    contains "${UPGRADE_RUNBOOK_FILE}" '10.11 -> 11.4 -> 11.8 -> 12.3'
    contains "${UPGRADE_RUNBOOK_FILE}" 'Do not set the inventory directly to `12.3`'
    contains "${UPGRADE_RUNBOOK_FILE}" 'mariadb-upgrade --skip-write-binlog'
    contains "${UPGRADE_RUNBOOK_FILE}" 'Never delete or recreate'
    contains "${UPGRADE_RUNBOOK_FILE}" 'innodb_fast_shutdown'
    contains "${UPGRADE_RUNBOOK_FILE}" 'apt-cache policy mariadb-server mariadb-client mariadb-backup galera-4'
    contains "${UPGRADE_RUNBOOK_FILE}" 'Do not continue to the next node if an SST starts during a mixed-version hop.'
    contains "${UPGRADE_RUNBOOK_FILE}" 'name=librenms-daily.timer state=stopped'
    contains "${UPGRADE_RUNBOOK_FILE}" 'name=librenms-daily.timer enabled=true state=started'
    contains "${UPGRADE_RUNBOOK_FILE}" '`maintenance-enter` has already stopped MariaDB'
    contains "${UPGRADE_RUNBOOK_FILE}" 'librenms_maintenance_resume_daily_timer=false'
    does_not_contain "${UPGRADE_RUNBOOK_FILE}" "sudo mysql -e 'SET GLOBAL innodb_fast_shutdown=1;'"
    contains "${MAINTENANCE_DEFAULTS_FILE}" 'librenms_maintenance_resume_daily_timer: true'
    contains "${MAINTENANCE_DEFAULTS_FILE}" 'librenms_maintenance_mariadb_socket_timeout: 120'
    contains "${MAINTENANCE_EXIT_FILE}" 'librenms_maintenance_resume_daily_timer | bool'
    contains "${MAINTENANCE_EXIT_FILE}" 'ansible.builtin.include_tasks: galera_rejoin.yml'
    contains "${MAINTENANCE_GALERA_REJOIN_FILE}" 'Reset failed target MariaDB unit state before normal rejoin'
    contains "${MAINTENANCE_GALERA_REJOIN_FILE}" 'Clear stale Galera bootstrap environment before normal rejoin'
    contains "${MAINTENANCE_GALERA_REJOIN_FILE}" 'Wait for target MariaDB socket after maintenance'
    contains "${MAINTENANCE_GALERA_REJOIN_FILE}" 'Fail with target Galera maintenance rejoin diagnostics'
    contains "${MAINTENANCE_GALERA_REJOIN_FILE}" 'No Galera bootstrap was attempted'
    does_not_contain "${MAINTENANCE_GALERA_REJOIN_FILE}" 'galera_new_cluster'

    printf 'MariaDB series guardrail test passed.\n'
}

main "$@"
