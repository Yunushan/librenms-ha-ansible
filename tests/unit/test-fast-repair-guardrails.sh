#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAYBOOK="${ROOT_DIR}/playbooks/fast-repair.yml"
TASKS="${ROOT_DIR}/roles/fast_repair/tasks/main.yml"
DEFAULTS="${ROOT_DIR}/roles/fast_repair/defaults/main.yml"
GLOBAL_DEFAULTS="${ROOT_DIR}/roles/librenms_defaults/defaults/main.yml"
DISPATCHER_HELPER="${ROOT_DIR}/roles/librenms_app/templates/librenms-dispatcher-ha-recover.py.j2"
RRD_PERMISSION_HELPER="${ROOT_DIR}/roles/librenms_app/templates/librenms-ha-rrd-permission-repair.sh.j2"
RRDCACHED_UNIT_PLAYBOOK="${ROOT_DIR}/playbooks/rrdcached-unit-repair.yml"
RRDCACHED_OVERRIDE="${ROOT_DIR}/roles/librenms_app/templates/rrdcached.systemd-override.conf.j2"
RRDCACHED_SOCKET_OVERRIDE="${ROOT_DIR}/roles/librenms_app/templates/rrdcached.socket.systemd-override.conf.j2"
RRDCACHED_DEFAULTS="${ROOT_DIR}/roles/librenms_app/templates/rrdcached.default.j2"
MAKEFILE="${ROOT_DIR}/Makefile"
FAST_REPAIR_DOC="${ROOT_DIR}/docs/fast-repair.md"
TEST_ROOT="$(mktemp -d)"
RENDERED_SCRIPT="${TEST_ROOT}/rendered-fast-repair.sh"
UNIT_FUNCTIONS="${TEST_ROOT}/unit-functions.sh"
STOP_FUNCTIONS="${TEST_ROOT}/stop-functions.sh"
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
  /^    unit_state\(\)/ { exit }
  in_functions { sub(/^    /, ""); print }
  /^    unit_exists\(\)/ {
    in_functions=1
    sub(/^    /, "")
    print
  }
' "${TASKS}" > "${UNIT_FUNCTIONS}"
sh -n "${UNIT_FUNCTIONS}"

awk '
  /^    print_unit_diagnostics\(\)/ { exit }
  in_functions { sub(/^    /, ""); print }
  /^    unit_stop_snapshot\(\)/ {
    in_functions=1
    sub(/^    /, "")
    print
  }
' "${TASKS}" > "${STOP_FUNCTIONS}"
sh -n "${STOP_FUNCTIONS}"

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
grep -q 'skipping LibreNMS maintenance timers until the dispatcher is active and registered' "${TASKS}"
grep -q 'print_unit_diagnostics "${unit}"' "${TASKS}"
grep -q 'if wait_until_active "${unit}"; then' "${TASKS}"
grep -q 'wait_until_stably_active()' "${TASKS}"
grep -q 'ensure_rrdcached_started()' "${TASKS}"
grep -q 'cleanup_stale_rrdcached_runtime()' "${TASKS}"
grep -q -- '--property=LoadState' "${TASKS}"
grep -q 'refusing unsafe RRDCacheD runtime path' "${TASKS}"
grep -q 'librenms_fast_repair_rrdcached_required:' "${DEFAULTS}"
grep -q 'systemctl_bounded start --no-block "${unit}"' "${TASKS}"
grep -q 'wait_until_stopped()' "${TASKS}"
grep -q -- '--property=ActiveState,SubState,MainPID,ControlPID,ControlGroup' "${TASKS}"
grep -q 'unit_cgroup_has_processes()' "${TASKS}"
grep -q 'unit_cgroup_process_ids()' "${TASKS}"
grep -q 'signal_unit_cgroup_processes()' "${TASKS}"
grep -q 'kill_unit_cgroup()' "${TASKS}"
grep -q 'print_unit_cgroup_process_diagnostics()' "${TASKS}"
grep -q 'CGROUP_ROOT=/sys/fs/cgroup' "${TASKS}"
grep -q '${CGROUP_ROOT}${unit_control_group}/cgroup.events' "${TASKS}"
grep -q '${CGROUP_ROOT}${unit_control_group}/cgroup.procs' "${TASKS}"
grep -q '${CGROUP_ROOT}${kill_control_group}/cgroup.kill' "${TASKS}"
grep -q 'uninterruptible kernel I/O' "${TASKS}"
grep -q 'controlled node reboot' "${TASKS}"
grep -q 'failed:\*|\*:auto-restart)' "${TASKS}"
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
grep -q 'replace_python_bool_assignment' "${TASKS}"
grep -q 'reconcile_dispatcher_recovery_policy()' "${TASKS}"
grep -q 'recover_dispatcher_registration()' "${TASKS}"
grep -q 'dispatcher recovery helper is missing or not executable' "${TASKS}"
grep -q 'librenms_fast_repair_dispatcher_recovery_enabled:' "${DEFAULTS}"
grep -q 'REQUIRE_LOCAL_GALERA_READY 1 DB_HOST' "${TASKS}"
grep -q 'cleared stale LibreNMS configuration cache' "${TASKS}"
grep -q 'refresh_php_fpm_for_runtime_db_change()' "${TASKS}"
grep -q 'librenms_dispatcher_failover_prune_unreachable_nodes: false' "${GLOBAL_DEFAULTS}"
grep -q 'librenms_rrd_permission_repair_recursive: false' "${GLOBAL_DEFAULTS}"
grep -q '{% if librenms_rrd_permission_repair_recursive | bool %}' "${RRD_PERMISSION_HELPER}"
grep -q 'sys.exit(1)' "${DISPATCHER_HELPER}"
grep -q 'Refreshed local dispatcher registration' "${DISPATCHER_HELPER}"
grep -q '^RemainAfterExit=no$' "${RRDCACHED_OVERRIDE}"
grep -q -- '-l {{ librenms_rrdcached_network_bind_address_effective }}:{{ librenms_rrdcached_bind_port }}' "${RRDCACHED_OVERRIDE}"
grep -q -- 'NETWORK_OPTIONS="-l {{ librenms_rrdcached_network_bind_address_effective }}:{{ librenms_rrdcached_bind_port }}"' "${RRDCACHED_DEFAULTS}"
grep -q 'librenms_rrdcached_socket_unit_name' "${GLOBAL_DEFAULTS}"
grep -q 'ListenStream=' "${RRDCACHED_SOCKET_OVERRIDE}"
grep -q -- 'ListenStream={{ librenms_rrdcached_socket }}' "${RRDCACHED_SOCKET_OVERRIDE}"
grep -q -- 'ListenStream={{ librenms_rrdcached_network_bind_address_effective }}:{{ librenms_rrdcached_bind_port }}' "${RRDCACHED_SOCKET_OVERRIDE}"
grep -q 'rrdcached.socket.systemd-override.conf.j2' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q 'librenms_rrdcached_unit_repair_confirm' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q 'librenms_manage_rrdcached_systemd_override' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q 'rrdcached.systemd-override.conf.j2' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q -- '--property=Type,RemainAfterExit,KillMode,DropInPaths,ExecStart,After' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q 'Read back the deployed RRDCacheD systemd drop-in' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q "'serviceRequiresMountsFor=' not in" "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q 'The service was not started, stopped, or' "${RRDCACHED_UNIT_PLAYBOOK}"
grep -q '^rrdcached-unit-repair:' "${MAKEFILE}"
grep -q '^rrdcached-unit-repair-ask-become-pass:' "${MAKEFILE}"
grep -q 'RRDCACHED_UNIT_REPAIR_CONFIRM=true' "${FAST_REPAIR_DOC}"

if grep -Eq '^After=.*\{%.*%\}[[:space:]]*$' "${RRDCACHED_OVERRIDE}"; then
    echo "RRDCacheD After= must not use an end-of-line Jinja block that trims its newline" >&2
    exit 1
fi

if grep -Eq '^[[:space:]]*-L[[:space:]]*\\$' "${RRDCACHED_OVERRIDE}"; then
    echo "RRDCacheD must not combine the default listener (-L) with the explicit network listener" >&2
    exit 1
fi

if grep -q -- 'NETWORK_OPTIONS="-L ' "${RRDCACHED_DEFAULTS}"; then
    echo "RRDCacheD defaults must not combine the default listener (-L) with the explicit network listener" >&2
    exit 1
fi

if grep -Eq 'state:[[:space:]]*(started|stopped|restarted)' "${RRDCACHED_UNIT_PLAYBOOK}"; then
    echo "RRDCacheD unit repair must not change service runtime state" >&2
    exit 1
fi

(
  probe() {
    case "${3:-}" in
      rrdcached|rrdcached.service) printf 'loaded\n' ;;
      shorthand.service) printf 'loaded\n' ;;
      masked.service) printf 'masked\n' ;;
      shorthand|missing|missing.service) printf 'not-found\n' ;;
      empty|empty.service) : ;;
      *) return 1 ;;
    esac
  }

  # shellcheck source=/dev/null
  source "${UNIT_FUNCTIONS}"
  unit_exists rrdcached
  unit_exists rrdcached.service
  unit_exists shorthand
  unit_exists masked.service

  if unit_exists missing; then
    echo "fast repair must reject a not-found systemd service" >&2
    exit 1
  fi
  if unit_exists empty; then
    echo "fast repair must reject an empty systemd LoadState response" >&2
    exit 1
  fi
)

(
  stop_sequence_count="${TEST_ROOT}/stop-sequence-count"
  stop_command_log="${TEST_ROOT}/stop-command-log"
  printf '0\n' > "${stop_sequence_count}"
  : > "${stop_command_log}"

  probe() {
    sequence_count="$(cat "${stop_sequence_count}")"
    sequence_count=$((sequence_count + 1))
    printf '%s\n' "${sequence_count}" > "${stop_sequence_count}"
    if [ "${sequence_count}" -eq 1 ]; then
      printf '%s\n' \
        'ActiveState=failed' \
        'SubState=auto-restart' \
        'MainPID=0' \
        'ControlPID=0' \
        'ControlGroup='
    else
      printf '%s\n' \
        'ActiveState=inactive' \
        'SubState=dead' \
        'MainPID=0' \
        'ControlPID=0' \
        'ControlGroup='
    fi
  }

  systemctl_bounded() {
    printf '%s\n' "$*" >> "${stop_command_log}"
  }

  POLL_DELAY=0
  # shellcheck source=/dev/null
  source "${STOP_FUNCTIONS}"
  wait_until_stopped rrdcached.service 2

  [ "$(cat "${stop_sequence_count}")" -eq 2 ]
  grep -q '^stop --no-block rrdcached.service$' "${stop_command_log}"
  grep -q '^reset-failed rrdcached.service$' "${stop_command_log}"
)

(
  cgroup_root="${TEST_ROOT}/cgroup"
  cgroup_path="/system.slice/rrdcached.service"
  mkdir -p "${cgroup_root}${cgroup_path}"
  printf 'populated 1\n' > "${cgroup_root}${cgroup_path}/cgroup.events"

  probe() {
    printf '%s\n' \
      'ActiveState=inactive' \
      'SubState=dead' \
      'MainPID=0' \
      'ControlPID=0' \
      "ControlGroup=${cgroup_path}"
  }

  CGROUP_ROOT="${cgroup_root}"
  POLL_DELAY=0
  # shellcheck source=/dev/null
  source "${STOP_FUNCTIONS}"

  if wait_until_stopped rrdcached.service 1; then
    echo "fast repair must not treat an orphaned unit cgroup as stopped" >&2
    exit 1
  fi

  sleep() {
    printf 'populated 0\n' > "${cgroup_root}${cgroup_path}/cgroup.events"
  }

  wait_until_stopped rrdcached.service 2
)

(
  cgroup_root="${TEST_ROOT}/signal-cgroup"
  cgroup_path="/system.slice/rrdcached.service"
  mkdir -p "${cgroup_root}${cgroup_path}"
  sleep 60 &
  sleeper_pid=$!
  trap 'kill "${sleeper_pid}" >/dev/null 2>&1 || true' EXIT
  printf '%s\n' "${sleeper_pid}" > "${cgroup_root}${cgroup_path}/cgroup.procs"

  CGROUP_ROOT="${cgroup_root}"
  # shellcheck source=/dev/null
  source "${STOP_FUNCTIONS}"
  signal_unit_cgroup_processes TERM "${cgroup_path}"

  wait "${sleeper_pid}" 2>/dev/null || true
  if kill -0 "${sleeper_pid}" 2>/dev/null; then
    echo "fast repair direct cgroup fallback did not signal the proven service PID" >&2
    exit 1
  fi
  trap - EXIT
)

(
  cgroup_root="${TEST_ROOT}/diagnostic-cgroup"
  cgroup_path="/system.slice/rrdcached.service"
  mkdir -p "${cgroup_root}${cgroup_path}"
  printf '%s\n' "$$" > "${cgroup_root}${cgroup_path}/cgroup.procs"

  probe() {
    case "$1" in
      systemctl)
        printf '%s\n' \
          'ActiveState=inactive' \
          'SubState=dead' \
          'MainPID=0' \
          'ControlPID=0' \
          "ControlGroup=${cgroup_path}"
        ;;
      ps)
        case "$*" in
          *'stat='*) printf 'D\n' ;;
          *) printf '%s 1 root D fuse_wait 00:10 rrdcached rrdcached\n' "$$" ;;
        esac
        ;;
      *) return 1 ;;
    esac
  }

  CGROUP_ROOT="${cgroup_root}"
  # shellcheck source=/dev/null
  source "${STOP_FUNCTIONS}"
  diagnostic_output="$(print_unit_cgroup_process_diagnostics rrdcached.service 2>&1)"
  grep -q 'uninterruptible kernel I/O' <<< "${diagnostic_output}"
  grep -q 'controlled node reboot' <<< "${diagnostic_output}"
)

(
  cgroup_root="${TEST_ROOT}/kill-cgroup"
  cgroup_path="/system.slice/rrdcached.service"
  mkdir -p "${cgroup_root}${cgroup_path}"
  : > "${cgroup_root}${cgroup_path}/cgroup.kill"

  CGROUP_ROOT="${cgroup_root}"
  # shellcheck source=/dev/null
  source "${STOP_FUNCTIONS}"
  kill_unit_cgroup "${cgroup_path}"
  grep -qx '1' "${cgroup_root}${cgroup_path}/cgroup.kill"
)

redis_start_line=$(grep -nF 'if [ "${REDIS_MODE}" = sentinel ]; then' "${TASKS}" | head -n 1 | cut -d: -f1)
rrdcached_start_line=$(grep -nF 'if ensure_rrdcached_started; then' "${TASKS}" | head -n 1 | cut -d: -f1)
dispatcher_start_line=$(grep -nF 'if ensure_started librenms.service; then' "${TASKS}" | head -n 1 | cut -d: -f1)
dispatcher_recovery_line=$(grep -nF 'if ! recover_dispatcher_registration; then' "${TASKS}" | head -n 1 | cut -d: -f1)
timer_start_line=$(grep -nF 'if [ "${LIBRENMS_READY}" = true ]; then' "${TASKS}" | head -n 1 | cut -d: -f1)
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

if [ "${dispatcher_recovery_line}" -le "${dispatcher_start_line}" ] || \
   [ "${dispatcher_recovery_line}" -ge "${timer_start_line}" ]; then
    echo "fast repair must recover dispatcher registration after service startup and before timers" >&2
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
EOF
cat > "${runtime_env}" <<'EOF'
DB_HOST=10.2.7.144
DB_PORT=3306
EOF
cat > "${dispatcher_recover}" <<'EOF'
#!/usr/bin/env python3
DB_HOST = "10.2.7.144"
PRUNE_UNREACHABLE_NODES = True
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
DISPATCHER_RECOVERY_ENABLED=true
DISPATCHER_PRUNE_UNREACHABLE=False

reconcile_runtime_db_endpoint
grep -qx 'DB_HOST=10.2.7.141' "${runtime_wait}"
grep -qx 'REQUIRE_LOCAL_GALERA_READY=1' "${runtime_wait}"
[ "$(grep -c '^REQUIRE_LOCAL_GALERA_READY=' "${runtime_wait}")" -eq 1 ]
grep -qx 'DB_HOST=10.2.7.141' "${runtime_env}"
grep -qx 'DB_HOST = "10.2.7.141"' "${dispatcher_recover}"
reconcile_dispatcher_recovery_policy
grep -qx 'PRUNE_UNREACHABLE_NODES = False' "${dispatcher_recover}"
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

printf 'REQUIRE_LOCAL_GALERA_READY=0\n' >> "${runtime_wait}"
if reconcile_runtime_db_endpoint 2>/dev/null; then
    echo "fast repair must reject duplicate local Galera guard assignments" >&2
    exit 1
fi

echo "fast repair guardrails passed"
