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
readonly DEFAULTS="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"

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

printf 'Load-balancer rollout guardrail test passed.\n'
