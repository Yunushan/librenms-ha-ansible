#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly HA_VARS_FILE="${ROOT_DIR}/inventories/ha/group_vars/all.yml"
readonly APP_TASKS="${ROOT_DIR}/roles/librenms_app/tasks/main.yml"
readonly PROBE_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-runtime-health.php.j2"
readonly NGINX_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/nginx-librenms.conf.j2"
readonly HAPROXY_TEMPLATE="${ROOT_DIR}/roles/haproxy_keepalived/templates/haproxy.cfg.j2"
readonly STARTUP_REPAIR_TEMPLATE="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"
readonly GALERA_DRAIN_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-node-drain.sh.j2"
readonly GALERA_AGENT_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent.sh.j2"
readonly GALERA_TASKS="${ROOT_DIR}/roles/galera/tasks/main.yml"
readonly SITE_PLAYBOOK="${ROOT_DIR}/playbooks/site.yml"
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
    local ha_vars
    local app_tasks
    local probe
    local nginx
    local haproxy
    local startup_repair
    local galera_drain
    local galera_agent
    local galera_tasks
    local site_playbook
    local readiness_defaults
    local readiness_tasks
    local integration_haproxy
    local integration_test

    defaults="$(tr -d '\r' < "${DEFAULTS_FILE}")"
    ha_vars="$(tr -d '\r' < "${HA_VARS_FILE}")"
    app_tasks="$(tr -d '\r' < "${APP_TASKS}")"
    probe="$(tr -d '\r' < "${PROBE_TEMPLATE}")"
    nginx="$(tr -d '\r' < "${NGINX_TEMPLATE}")"
    haproxy="$(tr -d '\r' < "${HAPROXY_TEMPLATE}")"
    startup_repair="$(tr -d '\r' < "${STARTUP_REPAIR_TEMPLATE}")"
    galera_drain="$(tr -d '\r' < "${GALERA_DRAIN_TEMPLATE}")"
    galera_agent="$(tr -d '\r' < "${GALERA_AGENT_TEMPLATE}")"
    galera_tasks="$(tr -d '\r' < "${GALERA_TASKS}")"
    site_playbook="$(tr -d '\r' < "${SITE_PLAYBOOK}")"
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
        "librenms_haproxy_web_runtime_check_interval: 1s" \
        "Runtime health checks must detect a failed web/database node promptly."
    require_contains \
        "${defaults}" \
        "librenms_haproxy_web_runtime_check_fall: 1" \
        "A failed database-aware probe must remove the web node immediately."
    require_contains \
        "${defaults}" \
        "librenms_haproxy_web_runtime_check_rise: 3" \
        "A recovered web node must prove stability before rejoining service."
    require_contains \
        "${defaults}" \
        "librenms_runtime_db_prefer_local_galera: >-" \
        "HA Galera must prefer local runtime database members by default."
    require_contains \
        "${ha_vars}" \
        "librenms_runtime_db_prefer_local_galera: true" \
        "The three-node HA sample must bypass the database VIP for local application traffic."
    require_contains \
        "${app_tasks}" \
        "Verify preferred local Galera runtime member is synced" \
        "Deployment must validate the local Galera member before publishing runtime configuration."
    require_contains \
        "${app_tasks}" \
        "wsrep_local_state_comment[ \\t]+Synced" \
        "The local runtime member must be synced before LibreNMS uses it."
    require_contains \
        "${app_tasks}" \
        "librenms_db_host | length == 0" \
        "An explicit runtime database host must override local Galera preference."
    require_contains \
        "${probe}" \
        "SELECT 1 AS ready" \
        "The runtime probe must make a fresh database readiness query."
    require_contains \
        "${probe}" \
        "wsrep_cluster_status" \
        "A local Galera runtime probe must reject non-Primary members."
    require_contains \
        "${probe}" \
        "wsrep_local_state_comment" \
        "A local Galera runtime probe must reject unsynced members."
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
        "${defaults}" \
        "librenms_galera_web_drain_path: /run/librenms-galera-drain" \
        "Galera maintenance must use an independent web drain marker."
    require_contains \
        "${defaults}" \
        'librenms_galera_web_drain_compat_path: "{{ librenms_daily_ha_drain_path }}"' \
        "The first Galera-drain rollout must reuse the already-deployed daily health marker."
    require_contains \
        "${galera_drain}" \
        'COMPAT_OWNERSHIP_PATH="${STATE_PATH}.compat-owned"' \
        "Compatibility marker cleanup must be ownership-safe."
    require_contains \
        "${galera_drain}" \
        'assert_no_conflicting_units' \
        "Galera convergence must not race an active daily update."
    require_contains \
        "${galera_drain}" \
        'stop_recorded_unit "${DAILY_TIMER_UNIT}"' \
        "Galera convergence must stop the daily timer before publishing drain markers."
    require_contains \
        "${galera_drain}" \
        'assert_unit_inactive "${DAILY_SERVICE_UNIT}"' \
        "Galera convergence must recheck the daily service after stopping its timer."
    require_contains \
        "${defaults}" \
        "librenms_galera_web_drain_unit_stop_timeout: 30" \
        "Galera drain must bound graceful worker shutdown."
    require_contains \
        "${defaults}" \
        "librenms_galera_web_drain_systemd_recovery_timeout: 180" \
        "Galera drain must bound systemd manager recovery."
    require_contains \
        "${galera_drain}" \
        'wait_for_systemd_manager' \
        "Galera drain must recover transient systemd manager outages."
    require_contains \
        "${galera_drain}" \
        'unit_active_state_with_recovery()' \
        "Galera drain must retry transient per-unit state query failures."
    require_contains \
        "${galera_drain}" \
        'recording active LibreNMS units before drain' \
        "Pre-drain active-unit discovery must use bounded state-query recovery."
    require_contains \
        "${galera_drain}" \
        'systemctl_bounded "${action}" --no-block "${unit}"' \
        "Galera drain must not block indefinitely on a systemd stop job."
    require_contains \
        "${galera_drain}" \
        'systemctl_bounded kill --kill-whom=all --signal=TERM "${unit}"' \
        "Galera drain must terminate a worker cgroup that ignores graceful stop."
    require_contains \
        "${galera_drain}" \
        'systemctl_bounded kill --kill-whom=all --signal=KILL "${unit}"' \
        "Galera drain must have a final bounded kill for a stuck worker cgroup."
    require_contains \
        "${galera_drain}" \
        'refusing cgroup signals for non-service unit' \
        "Galera drain must never signal processless timer units."
    require_contains \
        "${galera_drain}" \
        "failed to quiesce a recorded unit; rolling back Galera drain" \
        "A failed worker stop must restore traffic before convergence aborts."
    require_contains \
        "${galera_drain}" \
        'queue_unit_action start "${unit}"' \
        "Rollback must use bounded, retryable systemd start requests."
    require_contains \
        "${galera_drain}" \
        'confirming rollback restoration before reopening traffic' \
        "Rollback must confirm systemd recovery before reopening traffic."
    require_contains \
        "${galera_drain}" \
        'leaving traffic drained because recorded LibreNMS units could not be restored' \
        "Rollback must fail closed when worker restoration cannot be confirmed."
    local daily_quiesce_line
    local drain_marker_line
    daily_quiesce_line="$(grep -n -m1 -- 'if ! quiesce_daily_timer; then' "${GALERA_DRAIN_TEMPLATE}" | cut -d: -f1)"
    drain_marker_line="$(grep -n -m1 -- '^  activate_web_drain_markers$' "${GALERA_DRAIN_TEMPLATE}" | cut -d: -f1)"
    [[ -n "${daily_quiesce_line}" && -n "${drain_marker_line}" \
        && "${daily_quiesce_line}" -lt "${drain_marker_line}" ]] \
        || fail "The daily timer must be quiesced before Galera publishes a web drain marker."
    require_contains \
        "${nginx}" \
        "librenms_galera_web_drain_path" \
        "Nginx health checks must reject a web node during local Galera maintenance."
    require_contains \
        "${nginx}" \
        "librenms_daily_ha_drain_enabled | bool or librenms_galera_web_drain_enabled | bool" \
        "The HAProxy health location must exist when either independent drain is enabled."
    require_contains \
        "${galera_tasks}" \
        "Enter local Galera drain before planned service convergence" \
        "Galera convergence must drain database and co-located web traffic before disruption."
    require_contains \
        "${galera_tasks}" \
        "Leave local Galera drain after convergence" \
        "Galera convergence must restore traffic after database readiness validation."
    require_contains \
        "${defaults}" \
        "librenms_galera_backend_drain_path: /run/librenms-galera-backend-drain" \
        "Galera maintenance must own a separate HAProxy backend drain marker."
    require_contains \
        "${defaults}" \
        "librenms_haproxy_db_shutdown_sessions_on_backend_down: false" \
        "Transient readiness failures must not terminate established SQL sessions."
    require_contains \
        "${galera_agent}" \
        "BACKEND_DRAIN_PATH" \
        "The Galera readiness agent must observe the planned backend drain marker."
    require_contains \
        "${galera_agent}" \
        "printf 'drain\\n'" \
        "The readiness agent must tell HAProxy to drain instead of fail a planned restart."
    require_contains \
        "${galera_drain}" \
        "if ! galera_ready; then" \
        "The drain helper must fail closed while the local database is unhealthy."
    require_contains \
        "${galera_drain}" \
        "information_schema.PROCESSLIST" \
        "The drain helper must wait for established database clients to quiesce."
    require_contains \
        "${galera_drain}" \
        "'unauthenticated user'" \
        "Transient HAProxy handshake probes must not block a planned database drain."
    require_contains \
        "${defaults}" \
        "librenms_galera_backend_force_disconnect_clients: true" \
        "Planned Galera convergence must retire persistent clients after its grace period."
    require_contains \
        "${galera_drain}" \
        "KILL CONNECTION" \
        "Planned Galera convergence must disconnect only lingering client sessions."
    require_contains \
        "${galera_drain}" \
        "wait_for_forced_client_disconnects" \
        "Galera convergence must verify lingering clients disconnected before disruption."
    require_contains \
        "${galera_drain}" \
        "EXPECT_MARIADB_RESTART" \
        "A planned restart may continue after the bounded final client reap."
    require_contains \
        "${galera_drain}" \
        "log_client_connections" \
        "Drain failures must record the remaining database client identities."
    require_contains \
        "${galera_drain}" \
        "stable_zero_polls" \
        "Galera convergence must tolerate replacement sessions during the bounded forced-drain grace period."
    require_contains \
        "${galera_drain}" \
        "active_php_fpm_services | sort -u" \
        "Galera convergence must quiesce active PHP-FPM units before draining database sessions."
    require_contains \
        "${galera_drain}" \
        "SYSTEMD_RECOVERY_RETRIES" \
        "Galera convergence must bound repeated systemd recovery attempts."
    require_contains \
        "${defaults}" \
        "librenms_galera_backend_force_disconnect_stable_polls: 2" \
        "Galera convergence must require stable zero-session observations before disruption."
    require_contains \
        "${defaults}" \
        "librenms_galera_web_drain_allow_stale_clients_before_restart: true" \
        "Role-managed restarts may finish a bounded drain after one persistent session races the reap."
    require_contains \
        "${defaults}" \
        "librenms_galera_web_drain_systemd_recovery_retries: 3" \
        "Galera convergence must configure a bounded systemd recovery retry budget."
    require_contains \
        "${galera_drain}" \
        'rm -f "${BACKEND_DRAIN_PATH}"' \
        "The HAProxy backend drain marker must be removed only by a guarded recovery path."
    require_contains \
        "${galera_drain}" \
        'sleep "${BACKEND_REJOIN_DELAY}"' \
        "The recovered database backend must be observed by HAProxy before web traffic resumes."
    require_contains \
        "${site_playbook}" \
        $'- name: Configure database hosts\n  hosts: librenms_db:!maintenance_nodes\n  become: true\n  gather_facts: true\n  serial: 1' \
        "Database convergence must remain serialized one Galera member at a time."
    local agent_line
    local config_line
    agent_line="$(grep -n -m1 -- '- name: Deploy Galera readiness agent$' "${GALERA_TASKS}" | cut -d: -f1)"
    config_line="$(grep -n -m1 -- '- name: Deploy Galera config$' "${GALERA_TASKS}" | cut -d: -f1)"
    [[ -n "${agent_line}" && -n "${config_line}" && "${agent_line}" -lt "${config_line}" ]] \
        || fail "The readiness agent must be active before a config-driven MariaDB restart can be drained."
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
        "librenms_web_validation_timeout: \"{{ librenms_web_validation_rrd_check_timeout }}\"" \
        "All validation result endpoints must share the long-running validation timeout."
    require_contains \
        "${haproxy}" \
        "acl librenms_validation path_reg -i ^/(?:index\\.php/)?validate/results(?:/|$)" \
        "Every validation result request must use the isolated validation backend."
    require_contains \
        "${haproxy}" \
        "timeout server {{ librenms_web_validation_timeout }}" \
        "The isolated validation backend must allow slow database and filesystem checks to finish."
    require_contains \
        "${nginx}" \
        "location ~* ^/(?:index\\.php/)?validate/results(?:/|$)" \
        "Nginx must apply the validation timeout to every validation result endpoint."
    require_contains \
        "${nginx}" \
        "fastcgi_read_timeout {{ librenms_web_validation_timeout }}" \
        "Nginx must not terminate non-RRD validation requests at the normal web timeout."
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
    require_contains \
        "${startup_repair}" \
        "enter_local_galera_web_drain" \
        "Startup repair must drain web traffic before restarting local Galera."
    require_contains \
        "${startup_repair}" \
        "exit_local_galera_web_drain" \
        "Startup repair must restore traffic after local Galera is synced."
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
