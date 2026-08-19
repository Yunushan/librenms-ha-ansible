#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly COMMON_TASKS_FILE="${ROOT_DIR}/roles/common/tasks/runtime_support.yml"
readonly COMMON_MAIN_FILE="${ROOT_DIR}/roles/common/tasks/main.yml"
readonly APP_TASKS_FILE="${ROOT_DIR}/roles/librenms_app/tasks/main.yml"
readonly WORKFLOW_FILE="${ROOT_DIR}/.github/workflows/lint.yml"
readonly SUPPORT_MATRIX_FILE="${ROOT_DIR}/docs/support-matrix.md"

fail() {
    printf 'Runtime support guardrail test failed: %s\n' "$1" >&2
    exit 1
}

contains() {
    local file="$1"
    local text="$2"
    grep -Fq -- "${text}" "${file}" ||
        fail "${file} does not contain: ${text}"
}

main() {
    local rrdtool_version_task

    contains "${DEFAULTS_FILE}" 'librenms_runtime_support_enabled: true'
    contains "${DEFAULTS_FILE}" '- "8.5"'
    contains "${DEFAULTS_FILE}" '- "3.14"'
    contains "${DEFAULTS_FILE}" '- "1.31"'
    contains "${DEFAULTS_FILE}" '- "1.10"'
    contains "${DEFAULTS_FILE}" '- 13'
    contains "${DEFAULTS_FILE}" 'Ubuntu:'
    contains "${DEFAULTS_FILE}" 'RedHat:'
    contains "${DEFAULTS_FILE}" '"Red Hat Enterprise Linux":'
    contains "${DEFAULTS_FILE}" 'Rocky:'
    contains "${DEFAULTS_FILE}" 'AlmaLinux:'
    contains "${DEFAULTS_FILE}" '    - "8"'
    contains "${DEFAULTS_FILE}" '    - "9"'
    contains "${DEFAULTS_FILE}" '    - "10"'
    contains "${COMMON_MAIN_FILE}" 'include_tasks: runtime_support.yml'
    contains "${COMMON_TASKS_FILE}" 'Validate supported distribution major version'
    contains "${COMMON_TASKS_FILE}" 'Validate supported Python runtime'
    contains "${COMMON_TASKS_FILE}" 'Validate supported RRDtool runtime'
    contains "${COMMON_TASKS_FILE}" 'Validate supported PHP runtime on managed web nodes'
    contains "${COMMON_TASKS_FILE}" 'Validate supported nginx runtime on managed web nodes'
    if [ "$(grep -Fc "regex_search('[0-9]+[.][0-9]+')" "${COMMON_TASKS_FILE}")" -ne 3 ]; then
        fail "${COMMON_TASKS_FILE} must use an unambiguous literal-dot version parser for Python, RRDtool, and nginx"
    fi
    contains "${COMMON_TASKS_FILE}" 'Command rc: {{ librenms_runtime_python_version_command.rc'
    contains "${COMMON_TASKS_FILE}" "default('<empty>', true)"
    contains "${APP_TASKS_FILE}" 'Validate resolved Laravel framework version'
    rrdtool_version_task="$(
        sed -n \
            '/^- name: Set LibreNMS rrdtool version after bootstrap$/,/^- name: Set dispatcher schedule types after bootstrap$/p' \
            "${APP_TASKS_FILE}"
    )"
    grep -Fq -- "| regex_search('[0-9]+\\\\.[0-9]+\\\\.[0-9]+')" <<<"${rrdtool_version_task}" ||
        fail "RRDtool post-bootstrap configuration must parse a semantic version"
    grep -Fq -- ') is not none' <<<"${rrdtool_version_task}" ||
        fail "RRDtool post-bootstrap version guard must return an explicit boolean"
    contains "${WORKFLOW_FILE}" 'python-version: "3.14"'
    contains "${SUPPORT_MATRIX_FILE}" '## Application Runtime Versions'
    contains "${SUPPORT_MATRIX_FILE}" 'Ubuntu 22.04/24.04/26.04'

    printf 'Runtime support guardrail test passed.\n'
}

main "$@"
