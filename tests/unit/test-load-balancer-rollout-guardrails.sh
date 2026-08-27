#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

require_rolling_load_balancer_play() {
    local playbook="$1"
    local block

    block="$(
        awk '
            /- name: (Configure load balancer and VIP hosts|Refresh HAProxy database listener for syslog workers)/ {
                capture=1
            }
            capture {
                print
            }
            capture && /^[[:space:]]*roles:/ {
                exit
            }
        ' "${playbook}"
    )"

    if ! grep -Fq "serial: 1" <<<"${block}"; then
        printf 'Load-balancer play must use serial: 1: %s\n' "${playbook}" >&2
        exit 1
    fi
}

require_rolling_load_balancer_play "${ROOT_DIR}/playbooks/site.yml"
require_rolling_load_balancer_play "${ROOT_DIR}/playbooks/syslog.yml"

readonly HAPROXY_TASKS="${ROOT_DIR}/roles/haproxy_keepalived/tasks/main.yml"
readonly HAPROXY_TEMPLATE="${ROOT_DIR}/roles/haproxy_keepalived/templates/haproxy.cfg.j2"
readonly KEEPALIVED_TEMPLATE="${ROOT_DIR}/roles/haproxy_keepalived/templates/keepalived.conf.j2"
readonly KEEPALIVED_HEALTH_TEMPLATE="${ROOT_DIR}/roles/haproxy_keepalived/templates/librenms-keepalived-haproxy-check.sh.j2"
readonly DEFAULTS="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"

require_file_text() {
    local file="$1"
    local expected="$2"
    local message="$3"

    if ! grep -Fq -- "${expected}" "${file}"; then
        printf '%s\nMissing in %s: %s\n' "${message}" "${file}" "${expected}" >&2
        exit 1
    fi
}

grep -Fq 'librenms_galera_readiness_agent_probe_timeout' "${HAPROXY_TASKS}" || {
    printf 'Galera agent preflight must use its bounded probe timeout.\n' >&2
    exit 1
}
grep -Fq 'librenms_galera_readiness_agent_probe_retries' "${HAPROXY_TASKS}" || {
    printf 'Galera agent preflight must retry during socket/cluster convergence.\n' >&2
    exit 1
}
probe_block="$(
    awk '
        /- name: Verify Galera readiness agents converge before HAProxy reload/ {
            capture=1
        }
        capture && /^- name:/ && !/Verify Galera readiness agents converge before HAProxy reload/ {
            exit
        }
        capture {
            print
        }
    ' "${HAPROXY_TASKS}"
)"
grep -Fq 'for ((attempt = 1; attempt <= PROBE_RETRIES; attempt++))' <<<"${probe_block}" || {
    printf 'Galera agent preflight must perform bounded retries inside one task result.\n' >&2
    exit 1
}
if grep -Eq '^[[:space:]]+(until|retries|delay):' <<<"${probe_block}"; then
    printf 'Galera agent preflight must not emit misleading Ansible retry failures.\n' >&2
    exit 1
fi
grep -Fq 'Ensure Galera readiness agent sockets are active before HAProxy reload' "${HAPROXY_TASKS}" || {
    printf 'HAProxy rollout must activate Galera readiness sockets before probing.\n' >&2
    exit 1
}
grep -Fq 'timeout check {{ librenms_galera_readiness_agent_check_timeout }}' "${HAPROXY_TEMPLATE}" || {
    printf 'Galera HAProxy checks need an agent-specific timeout.\n' >&2
    exit 1
}
query_timeout=$(awk '$1 == "librenms_galera_readiness_agent_query_timeout:" { print $2 }' "${DEFAULTS}")
check_timeout=$(awk '$1 == "librenms_galera_readiness_agent_check_timeout:" { print $2 }' "${DEFAULTS}")
probe_timeout=$(awk '$1 == "librenms_galera_readiness_agent_probe_timeout:" { print $2 }' "${DEFAULTS}")
probe_retries=$(awk '$1 == "librenms_galera_readiness_agent_probe_retries:" { print $2 }' "${DEFAULTS}")
check_timeout=${check_timeout%s}
probe_timeout=${probe_timeout%s}

if [[ ! "${query_timeout}" =~ ^[0-9]+$ || ! "${check_timeout}" =~ ^[0-9]+$ \
    || ! "${probe_timeout}" =~ ^[0-9]+$ || ! "${probe_retries}" =~ ^[0-9]+$ ]]; then
    printf 'Galera readiness time budgets must be explicit integer seconds.\n' >&2
    exit 1
fi
if ((check_timeout <= query_timeout || probe_timeout <= query_timeout)); then
    printf 'Galera readiness callers must outlive the agent query timeout.\n' >&2
    exit 1
fi
if ((probe_retries < 2)); then
    printf 'Galera readiness deployment preflight must allow convergence retries.\n' >&2
    exit 1
fi

require_file_text "${HAPROXY_TASKS}" \
    'src: librenms-keepalived-haproxy-check.sh.j2' \
    'Keepalived must receive a deployed data-plane health check.'
require_file_text "${HAPROXY_TASKS}" \
    'validate: "/bin/sh -n %s"' \
    'The Keepalived health check must pass shell syntax validation before deployment.'
require_file_text "${KEEPALIVED_TEMPLATE}" \
    'script "{{ librenms_keepalived_haproxy_check_path }}"' \
    'Keepalived must execute the data-plane health check.'
require_file_text "${KEEPALIVED_TEMPLATE}" \
    'weight {{ librenms_keepalived_haproxy_check_weight }}' \
    'Keepalived must adjust node priority when HAProxy data-plane checks fail.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'local_database_ready()' \
    'The Keepalived health check must validate local Galera readiness.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'LOCAL_DB_MEMBER=' \
    'The Keepalived health check must know whether the local host is a database member.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    '[ "${LOCAL_DB_MEMBER}" = 1 ] || return 0' \
    'Non-database nodes must not fail the local database/readiness probe.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'readiness_agent_ready()' \
    'Keepalived must reject a node with a broken Galera readiness socket.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'web_frontend_ready()' \
    'The VIP owner must pass a real web frontend probe.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'command -v curl >/dev/null 2>&1 || return 1' \
    'The VIP owner must fail closed when its web probe dependency is missing.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'if vip_is_local; then' \
    'Only the current VIP owner should validate the VIP listener path.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'has_listener "${VIP}" "${DB_PORT}"' \
    'The VIP owner must expose the database listener.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'vip_database_ready' \
    'The VIP owner must pass a real database login probe.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'haproxy -c -f "${HAPROXY_CONFIG}"' \
    'The Keepalived health check must reject invalid HAProxy configuration.'
require_file_text "${KEEPALIVED_HEALTH_TEMPLATE}" \
    'command -v timeout >/dev/null 2>&1' \
    'The Keepalived health check must verify its timeout dependency.'

printf 'Load-balancer rollout guardrail test passed.\n'
