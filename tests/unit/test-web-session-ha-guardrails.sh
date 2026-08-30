#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly ENV_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms.env.j2"
readonly SESSION_PROBE="${ROOT_DIR}/roles/librenms_app/templates/librenms-session-health.php.j2"
readonly RUNTIME_HEALTH="${ROOT_DIR}/roles/librenms_app/templates/librenms-runtime-health.php.j2"
readonly APP_TASKS="${ROOT_DIR}/roles/librenms_app/tasks/main.yml"
readonly REDIS_TASKS="${ROOT_DIR}/roles/redis_sentinel/tasks/main.yml"
readonly REDIS_CONFIG="${ROOT_DIR}/roles/redis_sentinel/templates/redis.conf.j2"
readonly HAPROXY_CONFIG="${ROOT_DIR}/roles/haproxy_keepalived/templates/haproxy.cfg.j2"
readonly STATUS_TASKS="${ROOT_DIR}/roles/ha_status/tasks/main.yml"

fail() {
    printf 'Web-session HA guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_contains() {
    local file="$1"
    local text="$2"
    local message="$3"

    grep -Fq -- "${text}" "${file}" || fail "${message}"
}

require_contains "${ENV_TEMPLATE}" 'SESSION_DRIVER=redis' \
    'Sentinel mode must select Redis-backed Laravel sessions.'
require_contains "${ENV_TEMPLATE}" 'SESSION_CONNECTION=sentinel_session' \
    'Sentinel mode must select the dedicated session connection.'

require_contains "${DEFAULTS}" "librenms_redis_persistence_enabled: \"{{ librenms_redis_mode == 'sentinel' }}\"" \
    'Redis persistence must be enabled by default in Sentinel mode.'
require_contains "${DEFAULTS}" 'librenms_redis_appendfsync: everysec' \
    'Sentinel AOF must use the production every-second fsync policy.'
require_contains "${REDIS_CONFIG}" 'appendfsync {{ librenms_redis_appendfsync }}' \
    'The managed Redis configuration must render the AOF fsync policy.'

require_contains "${REDIS_TASKS}" 'Enable AOF against the live Redis dataset before managed restart' \
    'AOF must be enabled live before Redis can restart.'
require_contains "${REDIS_TASKS}" 'Wait for live Redis AOF rewrite before managed restart' \
    'Redis convergence must wait for the initial AOF rewrite.'

live_aof_line="$(grep -n -m1 -- 'Enable AOF against the live Redis dataset before managed restart' "${REDIS_TASKS}" | cut -d: -f1)"
config_deploy_line="$(grep -n -m1 -- 'Deploy Redis server config' "${REDIS_TASKS}" | cut -d: -f1)"
[[ -n "${live_aof_line}" && -n "${config_deploy_line}" && "${live_aof_line}" -lt "${config_deploy_line}" ]] \
    || fail 'The live AOF migration must precede the managed Redis config restart.'

require_contains "${HAPROXY_CONFIG}" 'cookie {{ librenms_haproxy_web_session_cookie_name }} insert indirect nocache httponly' \
    'HAProxy must issue a web-backend persistence cookie.'
require_contains "${HAPROXY_CONFIG}" "cookie {{ host | regex_replace('[^A-Za-z0-9_.-]', '_') }}" \
    'HAProxy cookie values must remain stable when maintenance changes the active host list.'

require_contains "${RUNTIME_HEALTH}" "config('session.connection')" \
    'HAProxy runtime health must inspect the Laravel session connection.'
require_contains "${RUNTIME_HEALTH}" "connection(\$sessionConnection)->command('ping', [])" \
    'HAProxy runtime health must probe the selected session Redis connection.'

require_contains "${APP_TASKS}" 'Deploy LibreNMS shared-session health probe' \
    'Application convergence must deploy the shared-session probe.'
require_contains "${SESSION_PROBE}" "if (\$action === 'write')" \
    'The session probe must support writing through Laravel.'
require_contains "${SESSION_PROBE}" "if (\$action === 'read')" \
    'The session probe must support reading through Laravel.'
require_contains "${SESSION_PROBE}" 'app_key_sha256=' \
    'The session probe must expose a non-secret APP_KEY parity digest.'
require_contains "${SESSION_PROBE}" 'session_secure=' \
    'The session probe must compare effective cookie security across web nodes.'

require_contains "${STATUS_TASKS}" 'Inspect LibreNMS runtime session configuration' \
    'Strict status must inspect every web node session configuration.'
require_contains "${STATUS_TASKS}" 'Write shared LibreNMS session continuity marker' \
    'Strict status must write a real Laravel session marker.'
require_contains "${STATUS_TASKS}" 'Read shared LibreNMS session continuity marker on every web node' \
    'Strict status must read the marker through every active web node.'
require_contains "${STATUS_TASKS}" 'Inspect live Redis session durability' \
    'Strict status must inspect AOF state on every active Redis node.'
require_contains "${STATUS_TASKS}" 'aof_last_write_status:ok' \
    'Strict status must reject a live Redis AOF write failure.'
require_contains "${STATUS_TASKS}" 'LibreNMS web nodes do not share one APP_KEY and session configuration.' \
    'Strict status must reject application-key or session-config drift.'

printf 'Web-session HA guardrail test passed.\n'
