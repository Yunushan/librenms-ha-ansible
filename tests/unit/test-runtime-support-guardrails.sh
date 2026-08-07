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
    contains "${APP_TASKS_FILE}" 'Validate resolved Laravel framework version'
    contains "${WORKFLOW_FILE}" 'python-version: "3.14"'
    contains "${SUPPORT_MATRIX_FILE}" '## Application Runtime Versions'
    contains "${SUPPORT_MATRIX_FILE}" 'Ubuntu 22.04/24.04/26.04'

    printf 'Runtime support guardrail test passed.\n'
}

main "$@"
