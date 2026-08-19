#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAYBOOK="${ROOT_DIR}/playbooks/fast-repair.yml"
TASKS="${ROOT_DIR}/roles/fast_repair/tasks/main.yml"
DEFAULTS="${ROOT_DIR}/roles/fast_repair/defaults/main.yml"
TEST_ROOT="$(mktemp -d)"
RENDERED_SCRIPT="${TEST_ROOT}/rendered-fast-repair.sh"
RECONCILE_FUNCTIONS="${TEST_ROOT}/reconcile-functions.sh"
trap 'rm -rf "${TEST_ROOT}"' EXIT

awk '
  /^  register: fast_repair_result$/ { exit }
  in_raw { sub(/^    /, ""); print }
  /^  ansible\.builtin\.raw: \|$/ { in_raw=1 }
' "${TASKS}" |
  sed -E 's/^([A-Z_]+)=\{\{.*\}\}$/\1=x/' > "${RENDERED_SCRIPT}"
sh -n "${RENDERED_SCRIPT}"

awk '
  /^    probe_readiness_socket\(\)/ { exit }
  in_functions { sub(/^    /, ""); print }
  /^    preserve_replacement_metadata\(\)/ {
    in_functions=1
    sub(/^    /, "")
    print
  }
' "${TASKS}" > "${RECONCILE_FUNCTIONS}"
sh -n "${RECONCILE_FUNCTIONS}"

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
grep -q 'skipping rrdcached until the RRD mount is healthy' "${TASKS}"
grep -q 'skipping LibreNMS maintenance timers until the runtime dependency gate passes' "${TASKS}"
grep -q 'print_unit_diagnostics "${unit}"' "${TASKS}"
grep -q 'if wait_until_active "${unit}"; then' "${TASKS}"
grep -q 'systemctl_bounded start --no-block "${unit}"' "${TASKS}"
grep -q 'wait_until_stopped()' "${TASKS}"
grep -q 'systemctl_bounded stop --no-block "${stop_unit}"' "${TASKS}"
grep -q 'systemctl_bounded kill --kill-whom=all --signal=TERM "${stop_unit}"' "${TASKS}"
grep -q 'systemctl_bounded kill --kill-whom=all --signal=KILL "${stop_unit}"' "${TASKS}"
grep -q 'if ! quiesce_stuck_units; then' "${TASKS}"
grep -q -- '--- librenms.service runtime gate ---' "${TASKS}"
grep -q 'repair_local_readiness()' "${TASKS}"
grep -q 'runtime_gate_ready()' "${TASKS}"
grep -q 'skipping librenms.service until its runtime dependency gate passes' "${TASKS}"
grep -q 'print_database_path_diagnostics' "${TASKS}"
grep -q 'librenms_fast_repair_local_galera_runtime:' "${DEFAULTS}"
grep -q "groups.get('librenms_db', \[\])" "${DEFAULTS}"
grep -q 'librenms_runtime_db_prefer_local_galera' "${DEFAULTS}"
grep -q 'reconcile_runtime_db_endpoint()' "${TASKS}"
grep -q 'replace_shell_assignment "${RUNTIME_WAIT_PATH}" DB_HOST "${DB_HOST}"' "${TASKS}"
grep -q 'replace_shell_assignment "${LIBRENMS_ENV_PATH}" DB_HOST "${DB_HOST}"' "${TASKS}"
grep -q 'replace_python_string_assignment "${DISPATCHER_RECOVER_PATH}" DB_HOST "${DB_HOST}"' "${TASKS}"
grep -q 'REQUIRE_LOCAL_GALERA_READY 1' "${TASKS}"
grep -q 'cleared stale LibreNMS configuration cache' "${TASKS}"
grep -q 'refresh_php_fpm_for_runtime_db_change()' "${TASKS}"

redis_start_line=$(grep -nF 'if [ "${REDIS_MODE}" = sentinel ]; then' "${TASKS}" | head -n 1 | cut -d: -f1)
rrdcached_start_line=$(grep -nF 'if ! ensure_started rrdcached; then' "${TASKS}" | head -n 1 | cut -d: -f1)
dispatcher_start_line=$(grep -nF 'if ! ensure_started librenms.service; then' "${TASKS}" | head -n 1 | cut -d: -f1)
runtime_gate_line=$(grep -nF 'if runtime_gate_ready; then' "${TASKS}" | head -n 1 | cut -d: -f1)
runtime_reconcile_line=$(grep -nF 'if [ "${GALERA_READY}" = true ] && ! reconcile_runtime_db_endpoint; then' "${TASKS}" | head -n 1 | cut -d: -f1)

if [ "${redis_start_line}" -ge "${dispatcher_start_line}" ] || \
   [ "${rrdcached_start_line}" -ge "${dispatcher_start_line}" ]; then
    echo "fast repair must start Redis and RRDCacheD before librenms.service" >&2
    exit 1
fi

if [ "${runtime_gate_line}" -ge "${dispatcher_start_line}" ]; then
    echo "fast repair must pass the runtime dependency gate before starting librenms.service" >&2
    exit 1
fi

if [ "${runtime_reconcile_line}" -ge "${runtime_gate_line}" ]; then
    echo "fast repair must reconcile the runtime database endpoint before running its dependency gate" >&2
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

runtime_root="${TEST_ROOT}/librenms"
runtime_wait="${TEST_ROOT}/librenms-ha-runtime-wait"
dispatcher_recover="${TEST_ROOT}/librenms-dispatcher-ha-recover"
runtime_env="${runtime_root}/.env"
config_cache="${runtime_root}/bootstrap/cache/config.php"
mkdir -p "$(dirname "${config_cache}")"
cat > "${runtime_wait}" <<'EOF'
#!/bin/sh
DB_HOST='10.2.7.144'
REQUIRE_LOCAL_GALERA_READY=0
EOF
cat > "${runtime_env}" <<'EOF'
DB_HOST=10.2.7.144
DB_PORT=3306
EOF
cat > "${dispatcher_recover}" <<'EOF'
#!/usr/bin/env python3
DB_HOST = "10.2.7.144"
EOF
printf 'stale cache\n' > "${config_cache}"
chmod 0750 "${runtime_wait}" "${dispatcher_recover}"
chmod 0640 "${runtime_env}"
runtime_wait_mode="$(stat -c '%a' "${runtime_wait}")"
runtime_env_mode="$(stat -c '%a' "${runtime_env}")"

# shellcheck source=/dev/null
source "${RECONCILE_FUNCTIONS}"
RECONCILE_RUNTIME_DB=true
DB_MODE=galera
GALERA_READY=true
DB_HOST=10.2.7.141
DB_PORT=3306
RUNTIME_WAIT_PATH="${runtime_wait}"
LIBRENMS_ENV_PATH="${runtime_env}"
DISPATCHER_RECOVER_PATH="${dispatcher_recover}"
LIBRENMS_DIR="${runtime_root}"
REPAIR_CHANGED=0
RUNTIME_DB_CHANGED=0
RUNTIME_ENV_CHANGED=0
LAST_REPLACE_CHANGED=0

reconcile_runtime_db_endpoint
grep -qx 'DB_HOST=10.2.7.141' "${runtime_wait}"
grep -qx 'REQUIRE_LOCAL_GALERA_READY=1' "${runtime_wait}"
grep -qx 'DB_HOST=10.2.7.141' "${runtime_env}"
grep -qx 'DB_HOST = "10.2.7.141"' "${dispatcher_recover}"
[ ! -e "${config_cache}" ]
[ "$(stat -c '%a' "${runtime_wait}")" = "${runtime_wait_mode}" ]
[ "$(stat -c '%a' "${runtime_env}")" = "${runtime_env_mode}" ]
[ "${REPAIR_CHANGED}" -eq 1 ]
[ "${RUNTIME_DB_CHANGED}" -eq 1 ]
[ "${RUNTIME_ENV_CHANGED}" -eq 1 ]

REPAIR_CHANGED=0
RUNTIME_DB_CHANGED=0
RUNTIME_ENV_CHANGED=0
LAST_REPLACE_CHANGED=0
reconcile_runtime_db_endpoint
[ "${REPAIR_CHANGED}" -eq 0 ]
[ "${RUNTIME_DB_CHANGED}" -eq 0 ]
[ "${RUNTIME_ENV_CHANGED}" -eq 0 ]

echo "fast repair guardrails passed"
