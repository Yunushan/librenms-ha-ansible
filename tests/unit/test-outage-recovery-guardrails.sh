#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULTS_FILE="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
readonly STARTUP_REPAIR="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-startup-repair.sh.j2"
readonly RUNTIME_WAIT="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-runtime-wait.sh.j2"
readonly HAPROXY_TEMPLATE="${ROOT_DIR}/roles/haproxy_keepalived/templates/haproxy.cfg.j2"
readonly SYSLOG_TASKS="${ROOT_DIR}/roles/librenms_syslog/tasks/main.yml"
readonly SYSLOG_TEMPLATE="${ROOT_DIR}/roles/librenms_syslog/templates/rsyslog-librenms.conf.j2"

require_text() {
    local file="$1"
    local expected="$2"
    local message="$3"

    if ! grep -Fq -- "${expected}" "${file}"; then
        printf '%s\nMissing in %s: %s\n' "${message}" "${file}" "${expected}" >&2
        exit 1
    fi
}

main() {
    local generic_units
    local recovery_block
    local guarded_recovery_line
    local generic_recovery_line
    local attempt_marker_line
    local systemd_action_line

    require_text "${DEFAULTS_FILE}" \
        'librenms_galera_self_heal_min_healthy_peers: 1' \
        'A normal member rejoin must require a verified healthy peer.'
    require_text "${DEFAULTS_FILE}" \
        'librenms_galera_self_heal_restart_cooldown: 600' \
        'Failed Galera recovery attempts must be rate-limited.'
    require_text "${STARTUP_REPAIR}" \
        'if [ "${DB_MODE}" = "galera" ] && [ "${unit}" = "${MARIADB_SERVICE}" ]; then' \
        'Generic service recovery must not bypass Galera quorum guards.'
    require_text "${STARTUP_REPAIR}" \
        'systemctl --no-block "${service_action}" "${MARIADB_SERVICE}"' \
        'Galera rejoin must use a bounded normal systemd service action.'
    require_text "${STARTUP_REPAIR}" \
        'wait_for_local_galera_ready' \
        'Recovery must wait for Primary, ready, and synced state.'
    require_text "${STARTUP_REPAIR}" \
        'journalctl -u "${MARIADB_SERVICE}"' \
        'A failed automatic rejoin must retain bounded diagnostics.'

    generic_units="$(
        awk '
            /^librenms_startup_repair_service_recovery_units:/ {
                capture=1
                print
                next
            }
            capture && /^[^[:space:]][^:]*:/ { exit }
            capture { print }
        ' "${DEFAULTS_FILE}"
    )"
    if grep -Fq 'librenms_mariadb_service_name' <<<"${generic_units}"; then
        printf 'MariaDB must not be part of generic systemd recovery.\n' >&2
        exit 1
    fi

    recovery_block="$(
        awk '
            /^recover_persistently_unready_local_galera\(\)/ { capture=1 }
            capture && /^mark_latest_db_gone_away_error_handled\(\)/ { exit }
            capture { print }
        ' "${STARTUP_REPAIR}"
    )"
    if grep -Eq 'galera_new_cluster|--wsrep-new-cluster|safe_to_bootstrap|grastate\.dat' \
        <<<"${recovery_block}"; then
        printf 'Automatic member recovery must never bootstrap a Galera cluster.\n' >&2
        exit 1
    fi

    attempt_marker_line="$(grep -n -F 'galera-restarted-at"' <<<"${recovery_block}" | tail -n 1 | cut -d: -f1)"
    systemd_action_line="$(grep -n -F 'systemctl --no-block' <<<"${recovery_block}" | cut -d: -f1)"
    if [[ -z "${attempt_marker_line}" || -z "${systemd_action_line}" \
        || "${attempt_marker_line}" -ge "${systemd_action_line}" ]]; then
        printf 'Galera cooldown marker must be written before the service action.\n' >&2
        exit 1
    fi

    guarded_recovery_line="$(grep -n -F 'recover_persistently_unready_local_galera || true' "${STARTUP_REPAIR}" | cut -d: -f1)"
    generic_recovery_line="$(grep -n -F 'recover_systemd_units || true' "${STARTUP_REPAIR}" | cut -d: -f1)"
    if [[ -z "${guarded_recovery_line}" || -z "${generic_recovery_line}" \
        || "${guarded_recovery_line}" -ge "${generic_recovery_line}" ]]; then
        printf 'Peer-aware Galera recovery must run before generic service recovery.\n' >&2
        exit 1
    fi

    require_text "${RUNTIME_WAIT}" \
        'REQUIRE_LOCAL_GALERA_READY=' \
        'Dispatcher startup must know when it depends on local Galera.'
    require_text "${RUNTIME_WAIT}" \
        'wsrep_local_state_comment[[:space:]]+Synced' \
        'Dispatcher startup must reject an unsynced local member.'
    require_text "${DEFAULTS_FILE}" \
        'librenms_haproxy_db_connection_logging_enabled: false' \
        'High-volume DB connection logging must be disabled by default.'
    require_text "${HAPROXY_TEMPLATE}" \
        '    no log' \
        'The HAProxy DB frontend must support suppressing routine connection logs.'

    require_text "${DEFAULTS_FILE}" \
        'librenms_syslog_action_queue_enabled: true' \
        'LibreNMS syslog ingestion must use a failure buffer by default.'
    require_text "${DEFAULTS_FILE}" \
        'librenms_syslog_action_queue_spool_dir: /var/spool/rsyslog/librenms' \
        'The LibreNMS queue must not take ownership of the global rsyslog spool.'
    require_text "${SYSLOG_TEMPLATE}" \
        'queue.filename="{{ librenms_syslog_action_queue_filename }}"' \
        'The syslog action queue must be disk-assisted.'
    require_text "${SYSLOG_TEMPLATE}" \
        'queue.maxDiskSpace="{{ librenms_syslog_action_queue_max_disk_space }}"' \
        'The syslog disk buffer must have a storage bound.'
    require_text "${SYSLOG_TEMPLATE}" \
        'action.resumeInterval="{{ librenms_syslog_action_resume_interval }}"' \
        'A failed syslog sink must not restart every second.'
    require_text "${SYSLOG_TEMPLATE}" \
        'action.resumeRetryCount="{{ librenms_syslog_action_resume_retry_count }}"' \
        'Buffered syslog delivery must retry after database recovery.'
    require_text "${SYSLOG_TASKS}" \
        'Ensure LibreNMS syslog action queue spool directory exists' \
        'Deployment must create the configured rsyslog spool directory.'
    require_text "${SYSLOG_TEMPLATE}" \
        '$msg contains "librenms-galera-readiness-agent@"' \
        'Successful readiness checks must not amplify a syslog sink outage.'
    require_text "${SYSLOG_TEMPLATE}" \
        '$msg contains "Deactivated successfully"' \
        'Only routine readiness-agent lifecycle messages should be suppressed.'

    printf 'Outage recovery guardrail test passed.\n'
}

main "$@"
