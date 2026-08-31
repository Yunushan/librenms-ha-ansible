#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly PLAYBOOK="${ROOT_DIR}/playbooks/session-continuity-repair.yml"
readonly DEFAULTS="${ROOT_DIR}/roles/session_continuity_repair/defaults/main.yml"
readonly MAIN_TASKS="${ROOT_DIR}/roles/session_continuity_repair/tasks/main.yml"
readonly PREFLIGHT_TASKS="${ROOT_DIR}/roles/session_continuity_repair/tasks/preflight.yml"
readonly REDIS_TASKS="${ROOT_DIR}/roles/session_continuity_repair/tasks/redis.yml"
readonly WEB_TASKS="${ROOT_DIR}/roles/session_continuity_repair/tasks/web.yml"
readonly MAKEFILE="${ROOT_DIR}/Makefile"

fail() {
    printf 'Session repair guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_file_text() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "${expected}" "${file}" ||
        fail "missing ${expected} in ${file}"
}

main() {
    require_file_text "${PLAYBOOK}" \
        'hosts: librenms_redis:!maintenance_nodes'
    require_file_text "${PLAYBOOK}" \
        'Enable Redis AOF live without restarting the active session store'
    require_file_text "${PLAYBOOK}" 'serial: 1'
    require_file_text "${DEFAULTS}" \
        'librenms_session_repair_confirm: false'
    require_file_text "${MAIN_TASKS}" \
        "inventory_hostname not in groups.get('maintenance_nodes', [])"
    require_file_text "${MAIN_TASKS}" \
        'inventory_hostname in librenms_session_repair_active_web_nodes'
    require_file_text "${PREFLIGHT_TASKS}" \
        '>= (librenms_redis_quorum | int)'
    require_file_text "${PREFLIGHT_TASKS}" 'SENTINEL'
    require_file_text "${PREFLIGHT_TASKS}" 'CKQUORUM'
    require_file_text "${PREFLIGHT_TASKS}" \
        'The configured inventory APP_KEY does not match any active web node.'
    require_file_text "${PREFLIGHT_TASKS}" \
        "librenms_session_repair_app_key_effective | hash('sha256')"
    require_file_text "${REDIS_TASKS}" \
        'Enable AOF against the live Redis session dataset'
    require_file_text "${REDIS_TASKS}" 'CONFIG'
    require_file_text "${REDIS_TASKS}" 'REWRITE'
    require_file_text "${REDIS_TASKS}" 'aof_last_write_status:ok'
    require_file_text "${WEB_TASKS}" \
        'Deploy LibreNMS shared-session health probe'
    require_file_text "${WEB_TASKS}" 'Reconcile anchored LibreNMS APP_KEY'
    require_file_text "${WEB_TASKS}" 'regexp: ^APP_KEY='
    require_file_text "${WEB_TASKS}" 'config:clear'
    require_file_text "${WEB_TASKS}" 'config:cache'
    require_file_text "${WEB_TASKS}" \
        'librenms_session_repair_config_cache.stat.exists | bool'
    require_file_text "${WEB_TASKS}" 'reload-or-restart'
    require_file_text "${WEB_TASKS}" \
        'Confirm PHP-FPM lifecycle is managed by this project'
    require_file_text "${WEB_TASKS}" \
        "'connection=sentinel_session'"
    require_file_text "${MAKEFILE}" 'session-repair-ask-become-pass:'
    require_file_text "${MAKEFILE}" \
        'set SESSION_REPAIR_CONFIRM=true'

    if grep -Eq -- 'state:[[:space:]]*(restarted|stopped)' "${REDIS_TASKS}"; then
        fail 'live session repair must not restart or stop Redis'
    fi

    printf 'Session repair guardrail test passed.\n'
}

main "$@"
