#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent.sh.j2"
readonly SERVICE_TEMPLATE="${ROOT_DIR}/roles/galera/templates/librenms-galera-readiness-agent@.service.j2"

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
    assert_output drain $'wsrep_cluster_status\tPrimary\nwsrep_ready\tON\nwsrep_local_state_comment\tSynced' present
    assert_output up $'wsrep_cluster_status\tPrimary\nwsrep_ready\tON\nwsrep_local_state_comment\tSynced'
    assert_output down $'wsrep_cluster_status\tNon-Primary\nwsrep_ready\tON\nwsrep_local_state_comment\tSynced'
    assert_output down $'wsrep_cluster_status\tPrimary\nwsrep_ready\tOFF\nwsrep_local_state_comment\tSynced'
    assert_output down $'wsrep_cluster_status\tPrimary\nwsrep_ready\tON\nwsrep_local_state_comment\tDonor/Desynced'

    grep -Fq 'TimeoutStartSec={{ librenms_galera_readiness_agent_service_timeout }}' "${SERVICE_TEMPLATE}" || {
        printf 'Readiness-agent service must have a bounded startup timeout.\n' >&2
        return 1
    }
    grep -Fq 'KillMode=control-group' "${SERVICE_TEMPLATE}" || {
        printf 'Readiness-agent service must terminate the whole probe cgroup.\n' >&2
        return 1
    }
    if grep -Fq 'systemctl is-active' "${TEMPLATE}"; then
        printf 'Readiness agent must not depend on an unbounded systemctl probe.\n' >&2
        return 1
    fi
    printf 'Galera readiness agent decision test passed.\n'
}

main "$@"
