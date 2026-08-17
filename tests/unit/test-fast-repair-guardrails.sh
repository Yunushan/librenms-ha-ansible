#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAYBOOK="${ROOT_DIR}/playbooks/fast-repair.yml"
TASKS="${ROOT_DIR}/roles/fast_repair/tasks/main.yml"

grep -q 'gather_facts: false' "${PLAYBOOK}"
grep -q 'ansible.builtin.raw:' "${TASKS}"
grep -q 'MariaDB/Galera bootstrap is never attempted' "${TASKS}"
grep -q 'FAST_REPAIR_RESULT=ok' "${TASKS}"

if grep -Eq 'systemctl(_bounded)?[[:space:]]+(start|restart)[[:space:]]+mariadb|safe_to_bootstrap|grastate\.dat' "${TASKS}"; then
    echo "fast repair must not bootstrap or mutate Galera state" >&2
    exit 1
fi

echo "fast repair guardrails passed"
