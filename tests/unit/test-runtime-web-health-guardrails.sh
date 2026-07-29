#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly PROBE_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-runtime-health.php.j2"
readonly NGINX_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/nginx-librenms.conf.j2"
readonly HAPROXY_TEMPLATE="${ROOT_DIR}/roles/haproxy_keepalived/templates/haproxy.cfg.j2"
readonly STARTUP_REPAIR_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"
readonly READINESS_DEFAULTS="${ROOT_DIR}/roles/production_readiness/defaults/main.yml"
readonly READINESS_TASKS="${ROOT_DIR}/roles/production_readiness/tasks/main.yml"
readonly INTEGRATION_HAPROXY="${ROOT_DIR}/tests/integration/haproxy-web/haproxy.cfg"
readonly INTEGRATION_TEST="${ROOT_DIR}/tests/integration/haproxy-web/test.sh"

fail() {
    printf 'Runtime web-health guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_contains() {
    local content="$1"
    local expected="$2"
    local description="$3"

    [[ "${content}" == *"${expected}"* ]] || fail "${description}"
}

main() {
    local defaults
    local probe
    local nginx
    local haproxy
    local startup_repair
    local readiness_defaults
    local readiness_tasks
    local integration_haproxy
    local integration_test

    defaults="$(tr -d '\r' < "${DEFAULTS_FILE}")"
    probe="$(tr -d '\r' < "${PROBE_TEMPLATE}")"
    nginx="$(tr -d '\r' < "${NGINX_TEMPLATE}")"
    haproxy="$(tr -d '\r' < "${HAPROXY_TEMPLATE}")"
    startup_repair="$(tr -d '\r' < "${STARTUP_REPAIR_TEMPLATE}")"
    readiness_defaults="$(tr -d '\r' < "${READINESS_DEFAULTS}")"
    readiness_tasks="$(tr -d '\r' < "${READINESS_TASKS}")"
    integration_haproxy="$(tr -d '\r' < "${INTEGRATION_HAPROXY}")"
    integration_test="$(tr -d '\r' < "${INTEGRATION_TEST}")"

    require_contains \
        "${defaults}" \
        "librenms_manage_web_runtime_health_probe" \
        "HA deployments must manage a PHP database runtime health probe by default."
    require_contains \
        "${defaults}" \
        "librenms_haproxy_web_runtime_check_enabled" \
        "HAProxy runtime health checks must be configurable."
    require_contains \
        "${defaults}" \
        "librenms_haproxy_web_runtime_check_interval: 3s" \
        "Runtime health checks must remove failed PHP workers promptly."
    require_contains \
        "${probe}" \
        "SELECT 1 AS ready" \
        "The runtime probe must make a fresh database readiness query."
    require_contains \
        "${probe}" \
        "catch (Throwable)" \
        "The runtime probe must convert database failures into an unhealthy response."
    require_contains \
        "${probe}" \
        "http_response_code(503)" \
        "The runtime probe must return HTTP 503 when the database is unavailable."
    require_contains \
        "${probe}" \
        "echo \"unavailable\\n\";" \
        "The runtime probe must not expose exception details."
    require_contains \
        "${nginx}" \
        "location = {{ librenms_nginx_runtime_health_check_path }}" \
        "Nginx must expose the runtime health probe on a dedicated route."
    require_contains \
        "${nginx}" \
        "SCRIPT_FILENAME {{ librenms_web_runtime_health_probe_path }}" \
        "Nginx must execute the managed runtime health probe."
    require_contains \
        "${nginx}" \
        "librenms_daily_ha_drain_path" \
        "Runtime health checks must respect the HA maintenance drain marker."
    require_contains \
        "${haproxy}" \
        "librenms_haproxy_web_runtime_check_enabled" \
        "HAProxy must select the runtime probe when it is enabled."
    require_contains \
        "${haproxy}" \
        "librenms_nginx_runtime_health_check_path" \
        "HAProxy must use the runtime health URI instead of a static response."
    require_contains \
        "${defaults}" \
        "librenms_startup_repair_restart_php_fpm_on_db_gone_away: >-" \
        "HA mode must enable guarded recovery for fresh SQLSTATE 2006 errors."
    require_contains \
        "${defaults}" \
        "librenms_startup_repair_reload_php_fpm_after_db_recovery: >-" \
        "HA mode must enable guarded PHP-FPM recovery after database restoration."
    require_contains \
        "${defaults}" \
        "librenms_startup_repair_db_readiness_marker:" \
        "Database readiness transitions must be persisted between repair runs."
    require_contains \
        "${startup_repair}" \
        "recover_php_fpm_after_db_recovery()" \
        "Startup repair must react when the database frontend recovers."
    require_contains \
        "${startup_repair}" \
        'previous_state}" != "unready"' \
        "Startup repair must reload workers only after an observed outage."
    require_contains \
        "${startup_repair}" \
        'PHP-FPM recovery cooldown is active"
    return 75' \
        "Cooldown-limited recovery must remain pending instead of being marked handled."
    require_contains \
        "${startup_repair}" \
        "mark_latest_db_gone_away_error_handled" \
        "A successful transition recovery must suppress duplicate log-triggered reloads."
    [[ "$(grep -c 'recover_php_fpm_after_db_recovery || true' "${STARTUP_REPAIR_TEMPLATE}")" -ge 2 ]] \
        || fail "Startup repair must sample DB readiness before and after service recovery."
    require_contains \
        "${readiness_defaults}" \
        "librenms_production_readiness_verify_runtime_web_health" \
        "Production readiness must verify runtime health by default in HA mode."
    require_contains \
        "${readiness_tasks}" \
        "Verify database runtime health on every active LibreNMS web node" \
        "Production readiness must test every active web node directly."
    require_contains \
        "${readiness_tasks}" \
        "librenms_nginx_runtime_health_check_path" \
        "Production readiness must use the same deep endpoint as HAProxy."
    require_contains \
        "${integration_haproxy}" \
        "option httpchk GET /runtime" \
        "The HAProxy integration must health-check the runtime endpoint."
    require_contains \
        "${integration_test}" \
        "touch /tmp/runtime-unhealthy" \
        "The HAProxy integration must simulate a reachable runtime failure."
    require_contains \
        "${integration_test}" \
        "application-ok" \
        "The HAProxy integration must prove the failed runtime backend still serves the application."

    printf 'Runtime web-health guardrail test passed.\n'
}

main "$@"
