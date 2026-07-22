#!/usr/bin/env bash
set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="${TEST_DIR}/compose.yml"
readonly PROJECT_NAME="librenms-galera-integration"
readonly ROOT_PASSWORD="integration-secret"
readonly TIMEOUT_SECONDS="${GALERA_TEST_TIMEOUT_SECONDS:-180}"
readonly NODES=(galera-1 galera-2 galera-3)

compose() {
    docker compose --project-name "${PROJECT_NAME}" --file "${COMPOSE_FILE}" "$@"
}

cleanup() {
    compose down --volumes --remove-orphans >/dev/null 2>&1 || true
}

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        printf 'Docker CLI is required to run this integration test.\n' >&2
        return 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        printf 'Docker Compose v2 is required to run this integration test.\n' >&2
        return 1
    fi
    if ! docker info >/dev/null 2>&1; then
        printf 'A running Docker engine is required to run this integration test.\n' >&2
        return 1
    fi
}

sql() {
    local node="$1"
    local statement="$2"

    compose exec -T "${node}" mariadb -uroot "-p${ROOT_PASSWORD}" -Nse "${statement}"
}

node_is_synced_in_cluster() {
    local node="$1"
    local expected_size="$2"
    local status

    status="$(sql "${node}" \
        "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_size', 'wsrep_cluster_status', 'wsrep_local_state_comment', 'wsrep_ready');" \
        2>/dev/null)" || return 1

    grep -Fxq $'wsrep_cluster_size\t'"${expected_size}" <<<"${status}" &&
        grep -Fxq $'wsrep_cluster_status\tPrimary' <<<"${status}" &&
        grep -Fxq $'wsrep_local_state_comment\tSynced' <<<"${status}" &&
        grep -Fxq $'wsrep_ready\tON' <<<"${status}"
}

all_nodes_are_synced() {
    local expected_size="$1"
    shift
    local node

    for node in "$@"; do
        node_is_synced_in_cluster "${node}" "${expected_size}" || return 1
    done
}

wait_for() {
    local description="$1"
    shift
    local deadline=$((SECONDS + TIMEOUT_SECONDS))

    until "$@"; do
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            printf 'Timed out waiting for %s.\n' "${description}" >&2
            return 1
        fi
        sleep 1
    done
}

row_count_is() {
    local node="$1"
    local expected="$2"
    local count

    count="$(sql "${node}" 'SELECT COUNT(*) FROM integration_state.events;' 2>/dev/null)" || return 1
    [ "${count}" = "${expected}" ]
}

main() {
    require_docker
    trap cleanup EXIT

    compose up --detach --quiet-pull
    wait_for 'three synced Galera members' all_nodes_are_synced 3 "${NODES[@]}"

    sql galera-1 \
        "CREATE DATABASE integration_state; CREATE TABLE integration_state.events (id INT PRIMARY KEY, value VARCHAR(64)) ENGINE=InnoDB; INSERT INTO integration_state.events VALUES (1, 'before-failover');"
    wait_for 'initial write replication to Galera followers' row_count_is galera-2 1
    wait_for 'initial write replication to every Galera follower' row_count_is galera-3 1

    # Do not stop the bootstrap node: restarting it would rerun --wsrep-new-cluster.
    # A non-bootstrap member exercises the intended rejoin path safely.
    compose stop galera-3
    wait_for 'a two-member synced Galera primary component' all_nodes_are_synced 2 galera-1 galera-2

    sql galera-1 "INSERT INTO integration_state.events VALUES (2, 'during-failover');"
    wait_for 'write replication after Galera primary-node loss' row_count_is galera-2 2

    compose start galera-3
    wait_for 'the stopped Galera node to rejoin and synchronize' all_nodes_are_synced 3 "${NODES[@]}"
    wait_for 'post-failover write replication to the rejoined node' row_count_is galera-3 2

    printf 'Galera integration test passed: quorum, write continuity, and rejoin replication verified.\n'
}

main "$@"
