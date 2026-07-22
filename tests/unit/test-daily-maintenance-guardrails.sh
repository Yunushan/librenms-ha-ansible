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
        'LIBRENMS_DAILY_HA_DRAIN_ENABLED="false"' \
        'The outer wrapper must retain the HA drain through post-update recovery.'
    require_contains \
        "${wrapper}" \
        'librenms_nginx_runtime_health_check_path if daily_runtime_health_enabled' \
        'HA maintenance must use the database runtime health endpoint after an update.'
    require_contains \
        "${wrapper_execution}" \
        'activate_ha_drain || exit $?' \
        'The lock holder must drain itself before daily maintenance.'
    require_order \
        "${wrapper_execution}" \
        'acquire_cluster_maintenance_lock' \
        'activate_ha_drain || exit $?' \
        'The wrapper must acquire or skip the shared lock before any local drain.'
    require_order \
        "${wrapper_execution}" \
        'post_daily_web_cache_repair' \
        'recover_web_health' \
        'The web health check must run after cache and PHP-FPM maintenance.'
    require_contains \
        "${wrapper}" \
        'post-update web health did not recover' \
        'An unhealthy application must fail daily maintenance instead of reporting a clean update.'
    require_contains \
        "${wrapper}" \
        'waiting for daily-update canary ${CANARY_HOST}' \
        'HA followers must wait for a deterministic healthy canary before maintenance.'
    require_order \
        "${wrapper_execution}" \
        'prepare_daily_canary_gate' \
        'acquire_cluster_maintenance_lock' \
        'Followers must pass the canary gate before they can contend for the shared lock.'
    require_order \
        "${wrapper_execution}" \
        'recover_web_health' \
        'mark_daily_canary_success || exit $?' \
        'The canary marker must only be written after local application recovery succeeds.'
    require_contains \
        "${wrapper}" \
        'daily-update canary did not complete healthy stabilization; skipping follower maintenance' \
        'Followers must skip rather than perform an unattended rollout after a failed canary.'
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
