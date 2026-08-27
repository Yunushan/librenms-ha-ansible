#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent.sh.j2"
readonly SERVER_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent-server.py.j2"
readonly SERVICE_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent.service.j2"
readonly SOCKET_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent.socket.j2"
readonly RESET_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent-reset.sh.j2"

assert_output() {
    local expected="$1"
    local status="$2"
    local drain_state="${3:-absent}"
    local actual

    actual="$(
        MOCK_STATUS="${status}" \
            MOCK_DRAIN_STATE="${drain_state}" \
            run_agent
    )"
    [ "${actual}" = "${expected}" ] || {
        printf 'Expected readiness agent output %s, got %s.\n' "${expected}" "${actual}" >&2
        return 1
    }
}

run_agent() {
    local temporary_dir
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "${temporary_dir}"' RETURN

    mkdir -p "${temporary_dir}/bin"
    cat >"${temporary_dir}/bin/timeout" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
    cat >"${temporary_dir}/bin/mysql" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_STATUS}"
EOF
    chmod +x "${temporary_dir}/bin/timeout" "${temporary_dir}/bin/mysql"

    if [ "${MOCK_DRAIN_STATE:-absent}" = "present" ]; then
        touch "${temporary_dir}/backend-drain"
    fi

    sed \
        -e 's@{{ librenms_mariadb_service_name | quote }}@"mariadb"@' \
        -e 's@{{ librenms_mariadb_socket | quote }}@"/run/mysqld/mysqld.sock"@' \
        -e "s@{{ librenms_galera_backend_drain_path | quote }}@\"${temporary_dir}/backend-drain\"@" \
        -e 's@{{ librenms_galera_readiness_agent_query_timeout | int }}@2@' \
        "${TEMPLATE}" >"${temporary_dir}/agent"
    chmod +x "${temporary_dir}/agent"

    PATH="${temporary_dir}/bin:${PATH}" "${temporary_dir}/agent"
}

main() {
    local fake_agent
    local rendered_server
    local temporary_dir

    assert_output drain $'wsrep_cluster_status\tPrimary\nwsrep_ready\tON\nwsrep_local_state_comment\tSynced' present
    assert_output up $'wsrep_cluster_status\tPrimary\nwsrep_ready\tON\nwsrep_local_state_comment\tSynced'
    assert_output down $'wsrep_cluster_status\tNon-Primary\nwsrep_ready\tON\nwsrep_local_state_comment\tSynced'
    assert_output down $'wsrep_cluster_status\tPrimary\nwsrep_ready\tOFF\nwsrep_local_state_comment\tSynced'
    assert_output down $'wsrep_cluster_status\tPrimary\nwsrep_ready\tON\nwsrep_local_state_comment\tDonor/Desynced'

    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "${temporary_dir}"' RETURN
    fake_agent="${temporary_dir}/agent"
    cat >"${fake_agent}" <<'EOF'
#!/usr/bin/env bash
printf 'up\n'
EOF
    chmod +x "${fake_agent}"
    rendered_server="${temporary_dir}/readiness-server.py"
    sed \
        -e "s@{{ librenms_galera_readiness_agent_path | to_json }}@\"${fake_agent}\"@" \
        -e 's@{{ (librenms_galera_readiness_agent_query_timeout | int) + 1 }}@3@' \
        -e 's@{{ librenms_galera_readiness_agent_refresh_interval | int }}@1@' \
        "${SERVER_TEMPLATE}" >"${rendered_server}"
    python3 -m py_compile "${rendered_server}"
    python3 - "${rendered_server}" <<'PY'
import os
import socket
import subprocess
import sys
import time


server_path = sys.argv[1]
listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(("127.0.0.1", 0))
listener.listen(128)
address = listener.getsockname()

wrapper = """
import os
import runpy
import sys
os.environ["LISTEN_PID"] = str(os.getpid())
os.environ["LISTEN_FDS"] = "1"
runpy.run_path(sys.argv[1], run_name="__main__")
"""


def install_socket_fd():
    os.dup2(listener.fileno(), 3, inheritable=True)


process = subprocess.Popen(
    [sys.executable, "-c", wrapper, server_path],
    close_fds=True,
    pass_fds=(listener.fileno(),),
    preexec_fn=install_socket_fd,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
listener.close()

try:
    for attempt in range(50):
        try:
            with socket.create_connection(address, timeout=0.5) as client:
                if client.makefile("r", encoding="ascii").readline().strip() == "up":
                    break
        except OSError:
            pass
        time.sleep(0.1)
    else:
        raise RuntimeError("persistent readiness server did not start")

    for _request in range(200):
        with socket.create_connection(address, timeout=1) as client:
            response = client.makefile("r", encoding="ascii").readline().strip()
            if response != "up":
                raise RuntimeError(f"unexpected readiness response: {response!r}")
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)

if process.returncode not in (0, -15):
    stdout, stderr = process.communicate()
    raise RuntimeError(
        f"persistent readiness server exited with {process.returncode}: {stdout} {stderr}"
    )
PY

    grep -Fq 'ExecStart=/usr/bin/python3 {{ librenms_galera_readiness_agent_server_path }}' "${SERVICE_TEMPLATE}" || {
        printf 'Readiness-agent service must run the persistent socket server.\n' >&2
        return 1
    }
    grep -Fq 'KillMode=control-group' "${SERVICE_TEMPLATE}" || {
        printf 'Readiness-agent service must terminate the whole probe cgroup.\n' >&2
        return 1
    }
    grep -Fq 'Restart=on-failure' "${SERVICE_TEMPLATE}" || {
        printf 'Persistent readiness-agent service must recover after a crash.\n' >&2
        return 1
    }
    grep -Fq 'Start persistent Galera readiness agent server' "${ROOT_DIR}/roles/galera/tasks/main.yml" || {
        printf 'Readiness-agent deployment must start the persistent server before HAProxy probes.\n' >&2
        return 1
    }
    grep -Fq 'Start persistent Galera readiness agent server after socket restart' "${ROOT_DIR}/roles/galera/handlers/main.yml" || {
        printf 'Readiness-agent recovery must start the persistent server after socket restart.\n' >&2
        return 1
    }
    grep -Fq 'Start persistent Galera readiness server after socket repair' "${ROOT_DIR}/playbooks/readiness-repair.yml" || {
        printf 'The standalone readiness repair must start the persistent server before probing it.\n' >&2
        return 1
    }
    grep -Fq 'Backlog={{ librenms_galera_readiness_agent_backlog | int }}' "${SOCKET_TEMPLATE}" || {
        printf 'Readiness-agent socket must use an explicit bounded backlog.\n' >&2
        return 1
    }
    grep -Fq 'Accept=no' "${SOCKET_TEMPLATE}" || {
        printf 'Readiness-agent socket must use one persistent service.\n' >&2
        return 1
    }
    grep -Fq 'Service={{ librenms_galera_readiness_agent_service_unit }}' "${SOCKET_TEMPLATE}" || {
        printf 'Readiness-agent socket must name its persistent service.\n' >&2
        return 1
    }
    grep -Fq 'systemctl_bounded stop --no-block "${SOCKET_UNIT}"' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must queue listener shutdown before reaping workers.\n' >&2
        return 1
    }
    grep -Fq 'systemctl_bounded is-active "${SOCKET_UNIT}"' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must verify listener shutdown before reaping workers.\n' >&2
        return 1
    }
    grep -Fq 'systemctl_bounded stop --no-block "${SERVICE_UNIT}"' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must stop the persistent service.\n' >&2
        return 1
    }
    grep -Fq '"${LEGACY_SERVICE_GLOB}"' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must reap legacy accepted workers during migration.\n' >&2
        return 1
    }
    grep -Fq -- '--state=active,activating,deactivating' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must enumerate only live worker instances.\n' >&2
        return 1
    }
    if grep -Fq -- 'list-units --all' "${RESET_TEMPLATE}"; then
        printf 'Readiness-agent reset must not enumerate inactive unit history.\n' >&2
        return 1
    fi
    if grep -Fq 'Accept=yes' "${SOCKET_TEMPLATE}"; then
        printf 'Readiness agent must not create a systemd service per HAProxy probe.\n' >&2
        return 1
    fi
    grep -Fq 'systemctl_bounded kill --kill-who=all --signal=TERM' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must terminate stale worker instances.\n' >&2
        return 1
    }
    grep -Fq 'readonly SERVER_PATH=' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must identify the persistent server process exactly.\n' >&2
        return 1
    }
    grep -Fq 'signal_server_processes KILL' "${RESET_TEMPLATE}" || {
        printf 'Readiness-agent reset must have a bounded process kill fallback.\n' >&2
        return 1
    }
    if grep -Fq 'systemctl is-active' "${TEMPLATE}"; then
        printf 'Readiness agent must not depend on an unbounded systemctl probe.\n' >&2
        return 1
    fi
    grep -Fq '</dev/null' "${TEMPLATE}" || {
        printf 'Readiness-agent database probes must not inherit the client socket as stdin.\n' >&2
        return 1
    }
    printf 'Galera readiness agent decision test passed.\n'
}

main "$@"
