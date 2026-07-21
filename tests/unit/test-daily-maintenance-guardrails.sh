#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly WRAPPER_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-daily-wrapper.sh.j2"
readonly LOCK_HELPER_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-daily-global-lock.php.j2"

fail() {
    printf 'Daily-maintenance guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_contains() {
    local content="$1"
    local expected="$2"
    local description="$3"

    [[ "${content}" == *"${expected}"* ]] || fail "${description}"
}

require_order() {
    local content="$1"
    local first="$2"
    local second="$3"
    local description="$4"
    local first_offset
    local second_offset

    first_offset="$(awk -v text="${content}" -v needle="${first}" 'BEGIN { print index(text, needle) }')"
    second_offset="$(awk -v text="${content}" -v needle="${second}" 'BEGIN { print index(text, needle) }')"
    [ "${first_offset}" -gt 0 ] && [ "${second_offset}" -gt "${first_offset}" ] || fail "${description}"
}

main() {
    local wrapper
    local wrapper_execution
    local helper

    wrapper="$(tr -d '\r' < "${WRAPPER_TEMPLATE}")"
    helper="$(tr -d '\r' < "${LOCK_HELPER_TEMPLATE}")"
    wrapper_execution="${wrapper#*DAILY_OUTPUT_LOG=\"\$(mktemp /tmp/librenms-daily-wrapper.XXXXXX)\"}"

    require_contains \
        "${wrapper}" \
        'LIBRENMS_DAILY_HA_DRAIN_ENABLED="${HA_DRAIN_ENABLED}"' \
        'The global-lock helper must receive the HA drain setting.'
    require_contains \
        "${wrapper_execution}" \
        'if [ "${GLOBAL_LOCK_ENABLED}" != "true" ]; then
    activate_ha_drain || exit $?' \
        'Global-lock contenders must not drain before the lock holder is known.'
    require_order \
        "${wrapper_execution}" \
        'acquire_cluster_maintenance_lock' \
        'if [ "${GLOBAL_LOCK_ENABLED}" != "true" ]; then' \
        'The wrapper must acquire or skip the shared lock before any local drain.'
    require_order \
        "${helper}" \
        'SELECT GET_LOCK' \
        'if ($drainEnabled)' \
        'The PHP helper must acquire the database lock before creating a drain marker.'
    require_order \
        "${helper}" \
        'if ($drainEnabled)' \
        '$status = runProcess($command, $installDir);' \
        'The lock holder must finish its drain delay before running daily maintenance.'
    require_order \
        "${helper}" \
        'if ($drainCreated && is_file($drainPath)' \
        'SELECT RELEASE_LOCK' \
        'The drain marker must be cleaned before the database lock is released.'

    printf 'Daily-maintenance drain guardrail test passed.\n'
}

main "$@"
