#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly TASKS_FILE="${ROOT_DIR}/roles/mariadb/tasks/main.yml"
readonly README_FILE="${ROOT_DIR}/README.md"
readonly OPERATIONS_FILE="${ROOT_DIR}/docs/operations.md"
readonly SUPPORT_MATRIX_FILE="${ROOT_DIR}/docs/support-matrix.md"

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
    contains "${TASKS_FILE}" 'librenms_mariadb_upstream_galera_supported_series'
    contains "${DEFAULTS_FILE}" 'librenms_ubuntu_mariadb_expected_series:'
    contains "${TASKS_FILE}" 'Enforce the supported Ubuntu distro MariaDB server series'
    contains "${TASKS_FILE}" '--mariadb-server-version=mariadb-{{ librenms_mariadb_upstream_series }}'
    contains "${TASKS_FILE}" 'checksum: "{{ librenms_mariadb_upstream_repo_setup_checksum }}"'
    does_not_contain "${TASKS_FILE}" 'librenms_mariadb_allow_experimental_series'
    contains "${README_FILE}" 'Community repository support is available for explicit `11.4`, `11.8`, and'
    contains "${OPERATIONS_FILE}" 'The supported local'
    contains "${OPERATIONS_FILE}" 'series are `11.4`, `11.8`, and `12.3`.'
    contains "${SUPPORT_MATRIX_FILE}" '| 12.3 | Supported | Not supported by this repository'

    printf 'MariaDB series guardrail test passed.\n'
}

main "$@"
