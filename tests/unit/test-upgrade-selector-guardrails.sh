#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly COMMON_TASKS_FILE="${ROOT_DIR}/roles/common/tasks/main.yml"
readonly NGINX_REPOS_FILE="${ROOT_DIR}/roles/common/tasks/nginx_repos.yml"
readonly REDHAT_REPOS_FILE="${ROOT_DIR}/roles/common/tasks/redhat_repos.yml"
readonly MARIADB_TASKS_FILE="${ROOT_DIR}/roles/mariadb/tasks/main.yml"
readonly OS_TASKS_FILE="${ROOT_DIR}/roles/os_upgrade/tasks/main.yml"
readonly OS_DEFAULTS_FILE="${ROOT_DIR}/roles/os_upgrade/defaults/main.yml"
readonly MARIADB_PREFLIGHT_FILE="${ROOT_DIR}/roles/mariadb_upgrade_preflight/tasks/main.yml"
readonly OS_PREFLIGHT_PLAYBOOK="${ROOT_DIR}/playbooks/os-upgrade-preflight.yml"
readonly OS_NODE_PLAYBOOK="${ROOT_DIR}/playbooks/os-upgrade-node.yml"
readonly MARIADB_PREFLIGHT_PLAYBOOK="${ROOT_DIR}/playbooks/mariadb-upgrade-preflight.yml"
readonly RUNTIME_TASKS_FILE="${ROOT_DIR}/roles/runtime_upgrade/tasks/main.yml"
readonly RUNTIME_DEFAULTS_FILE="${ROOT_DIR}/roles/runtime_upgrade/defaults/main.yml"
readonly RUNTIME_PLAYBOOK="${ROOT_DIR}/playbooks/runtime-upgrade.yml"
readonly MAKEFILE="${ROOT_DIR}/Makefile"
readonly DOCS_FILE="${ROOT_DIR}/docs/upgrades.md"

fail() {
    printf 'Upgrade selector guardrail test failed: %s\n' "$1" >&2
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
    contains "${DEFAULTS_FILE}" 'librenms_os_upgrade_supported_transitions:'
    contains "${DEFAULTS_FILE}" 'librenms_nginx_channel: distro'
    contains "${DEFAULTS_FILE}" 'librenms_nginx_package_state: present'
    contains "${DEFAULTS_FILE}" 'librenms_nginx_official_repository_key_fingerprint: ""'
    contains "${DEFAULTS_FILE}" 'librenms_mariadb_selection_mode: distro'
    contains "${DEFAULTS_FILE}" 'librenms_mariadb_lts_series: "11.8"'
    contains "${DEFAULTS_FILE}" '- "11.4"'
    contains "${DEFAULTS_FILE}" '- "11.8"'
    contains "${DEFAULTS_FILE}" '- "12.3"'
    contains "${DEFAULTS_FILE}" 'librenms_redhat_mariadb_supported_streams_by_major:'

    contains "${COMMON_TASKS_FILE}" 'Configure Nginx package repository policy'
    contains "${COMMON_TASKS_FILE}" 'Update Debian Nginx package within the configured repository policy'
    contains "${COMMON_TASKS_FILE}" 'librenms_nginx_package_version'
    contains "${COMMON_TASKS_FILE}" 'Reject exact PHP selection on the native EL10 path'
    contains "${ROOT_DIR}/roles/common/tasks/runtime_support.yml" 'Validate the selected Nginx series is active'
    contains "${NGINX_REPOS_FILE}" 'Signed-By:'
    contains "${NGINX_REPOS_FILE}" 'gpgcheck=1'
    contains "${NGINX_REPOS_FILE}" 'mainline'
    contains "${NGINX_REPOS_FILE}" 'Validate the official Nginx signing-key fingerprint'
    contains "${REDHAT_REPOS_FILE}" 'Refuse an installed EL MariaDB major stream change during convergence'

    contains "${OS_TASKS_FILE}" 'librenms_os_upgrade_action'
    contains "${OS_TASKS_FILE}" 'librenms_os_upgrade_execute_command'
    contains "${OS_TASKS_FILE}" 'librenms_os_upgrade_target_distribution_key'
    contains "${OS_TASKS_FILE}" 'librenms_os_upgrade_current_min_version'
    contains "${OS_TASKS_FILE}" 'Automatic reboot: disabled'
    contains "${OS_DEFAULTS_FILE}" 'librenms_os_upgrade_require_maintenance: true'
    contains "${OS_TASKS_FILE}" 'librenms_os_upgrade_maintenance_marker_path'
    contains "${OS_TASKS_FILE}" 'ansible.builtin.shell'
    does_not_contain "${OS_TASKS_FILE}" 'do-release-upgrade'
    does_not_contain "${OS_TASKS_FILE}" 'dnf system-upgrade'
    does_not_contain "${OS_TASKS_FILE}" 'reboot: true'
    contains "${OS_PREFLIGHT_PLAYBOOK}" 'serial: 1'
    contains "${OS_PREFLIGHT_PLAYBOOK}" 'any_errors_fatal: true'
    contains "${OS_NODE_PLAYBOOK}" 'serial: 1'
    contains "${OS_NODE_PLAYBOOK}" 'any_errors_fatal: true'

    contains "${MARIADB_PREFLIGHT_FILE}" 'read-only'
    contains "${MARIADB_PREFLIGHT_FILE}" 'mariadb-upgrade'
    contains "${MARIADB_PREFLIGHT_FILE}" 'librenms_mariadb_preflight_repository_mode_effective != '\''upstream'\'''
    contains "${MARIADB_TASKS_FILE}" "ansible_facts.os_family == 'RedHat'"
    contains "${MARIADB_PREFLIGHT_PLAYBOOK}" 'serial: 1'
    contains "${MARIADB_PREFLIGHT_PLAYBOOK}" 'any_errors_fatal: true'
    contains "${MARIADB_TASKS_FILE}" 'librenms_mariadb_upstream_series_effective'

    contains "${RUNTIME_DEFAULTS_FILE}" 'librenms_runtime_upgrade_require_maintenance: true'
    contains "${RUNTIME_DEFAULTS_FILE}" 'librenms_runtime_upgrade_mariadb_confirm: false'
    contains "${RUNTIME_TASKS_FILE}" 'ansible_play_hosts_all | length == 1'
    contains "${RUNTIME_TASKS_FILE}" 'librenms_runtime_upgrade_mariadb_confirm | bool'
    contains "${RUNTIME_TASKS_FILE}" 'librenms_runtime_upgrade_maintenance_marker_path'
    contains "${RUNTIME_TASKS_FILE}" 'Reject exact PHP selection on the native EL10 path'
    contains "${RUNTIME_TASKS_FILE}" 'No OS release upgrade, MariaDB major-series change'
    if grep -nE '^  fail_msg:' "${COMMON_TASKS_FILE}" "${RUNTIME_TASKS_FILE}"; then
        fail 'assert fail_msg must be nested under its module'
    fi
    contains "${RUNTIME_PLAYBOOK}" 'serial: 1'
    contains "${RUNTIME_PLAYBOOK}" 'any_errors_fatal: true'

    contains "${MAKEFILE}" 'os-upgrade-preflight:'
    contains "${MAKEFILE}" 'os-upgrade-node:'
    contains "${MAKEFILE}" 'mariadb-upgrade-preflight:'
    contains "${MAKEFILE}" 'OS_UPGRADE_CONFIRM=true'
    contains "${MAKEFILE}" 'OS_UPGRADE_EXECUTE=true'
    contains "${MAKEFILE}" 'runtime-upgrade:'
    contains "${MAKEFILE}" 'runtime-upgrade-ask-become-pass:'
    contains "${MAKEFILE}" 'RUNTIME_UPGRADE_COMPONENTS'
    contains "${MAKEFILE}" 'RUNTIME_UPGRADE_MARIADB_CONFIRM'

    contains "${DOCS_FILE}" 'make os-upgrade-preflight'
    contains "${DOCS_FILE}" 'make os-upgrade-node'
    contains "${DOCS_FILE}" 'make mariadb-upgrade-preflight'
    contains "${DOCS_FILE}" 'stable'
    contains "${DOCS_FILE}" 'mainline'
    contains "${DOCS_FILE}" '12.3'
    contains "${DOCS_FILE}" 'one node at a time'
    contains "${DOCS_FILE}" 'make runtime-upgrade-ask-become-pass'
    contains "${DOCS_FILE}" 'RUNTIME_UPGRADE_MARIADB_CONFIRM=true'
    contains "${DOCS_FILE}" 'package-only'
    contains "${DOCS_FILE}" 'EL10 uses its native package stream'
    contains "${MARIADB_TASKS_FILE}" 'Require supplemental repositories for explicit EL MariaDB stream selection'

    printf 'Upgrade selector guardrail test passed.\n'
}

main "$@"
