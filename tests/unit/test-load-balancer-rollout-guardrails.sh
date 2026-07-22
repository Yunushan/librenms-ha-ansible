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

printf 'Load-balancer rollout guardrail test passed.\n'
