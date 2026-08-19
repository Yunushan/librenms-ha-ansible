#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAYBOOK="${ROOT_DIR}/playbooks/fast-repair.yml"
TASKS="${ROOT_DIR}/roles/fast_repair/tasks/main.yml"

grep -q 'gather_facts: false' "${PLAYBOOK}"
grep -q 'ansible.builtin.raw:' "${TASKS}"
grep -q 'MariaDB/Galera bootstrap is never attempted' "${TASKS}"
grep -q 'FAST_REPAIR_RESULT=ok' "${TASKS}"
grep -q 'systemctl_bounded enable' "${TASKS}"
grep -q 'after .*bounded probes' "${TASKS}"
grep -q 'RRD_READY=false' "${TASKS}"
grep -q 'librenms-fast-repair-probe' "${TASKS}"
grep -q 'probe test -d "${RRD_PATH}"' "${TASKS}"
grep -q 'print_rrd_mount_diagnostics' "${TASKS}"
grep -q "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_status','wsrep_local_state_comment')" "${TASKS}"
grep -q 'skipping librenms.service until the RRD mount is healthy' "${TASKS}"
grep -q 'skipping rrdcached until the RRD mount is healthy' "${TASKS}"
grep -q 'skipping LibreNMS maintenance timers until the RRD mount is healthy' "${TASKS}"
grep -q 'print_unit_diagnostics "${unit}"' "${TASKS}"
grep -q 'if wait_until_active "${unit}"; then' "${TASKS}"

redis_start_line=$(grep -nF 'if [ "${REDIS_MODE}" = sentinel ]; then' "${TASKS}" | head -n 1 | cut -d: -f1)
rrdcached_start_line=$(grep -nF 'if ! ensure_started rrdcached; then' "${TASKS}" | head -n 1 | cut -d: -f1)
dispatcher_start_line=$(grep -nF 'if ! ensure_started librenms.service; then' "${TASKS}" | head -n 1 | cut -d: -f1)

if [ "${redis_start_line}" -ge "${dispatcher_start_line}" ] || \
   [ "${rrdcached_start_line}" -ge "${dispatcher_start_line}" ]; then
    echo "fast repair must start Redis and RRDCacheD before librenms.service" >&2
    exit 1
fi

if grep -Eq 'systemctl(_bounded)?[[:space:]]+(start|restart)[[:space:]]+mariadb|safe_to_bootstrap|grastate\.dat' "${TASKS}"; then
    echo "fast repair must not bootstrap or mutate Galera state" >&2
    exit 1
fi

if grep -q '@@wsrep_cluster_status' "${TASKS}"; then
    echo "fast repair must query Galera status variables with SHOW GLOBAL STATUS" >&2
    exit 1
fi

echo "fast repair guardrails passed"
