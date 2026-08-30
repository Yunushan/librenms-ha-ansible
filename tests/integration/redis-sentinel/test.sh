#!/usr/bin/env bash
set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="${TEST_DIR}/compose.yml"
readonly PROJECT_NAME="librenms-redis-sentinel-integration"
readonly SENTINELS=(sentinel-1 sentinel-2 sentinel-3)
readonly TIMEOUT_SECONDS="${REDIS_SENTINEL_TEST_TIMEOUT_SECONDS:-180}"
readonly ORIGINAL_MASTER="172.30.77.11:6379"

compose() {
    docker compose --project-name "${PROJECT_NAME}" --file "${COMPOSE_FILE}" "$@"
}

cleanup() {
    compose down --volumes --remove-orphans >/dev/null 2>&1 || true
}

wait_for() {
    local description="$1"
    shift
    local deadline=$((SECONDS + TIMEOUT_SECONDS))

    until "$@"; do
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            printf 'Timed out waiting for %s\n' "${description}" >&2
            return 1
        fi
        sleep 1
    done
}

sentinel_master() {
    local sentinel="$1"
    compose exec -T "${sentinel}" redis-cli --raw -p 26379 \
        SENTINEL get-master-addr-by-name mymaster | paste -sd: -
}

all_sentinels_agree_on() {
    local expected="$1"
    local sentinel

    for sentinel in "${SENTINELS[@]}"; do
        [ "$(sentinel_master "${sentinel}")" = "${expected}" ] || return 1
    done
}

sentinel_knows_replicas() {
    local sentinel="$1"
    local master_info

    master_info="$(compose exec -T "${sentinel}" redis-cli --raw -p 26379 SENTINEL master mymaster)"
    [ "$(awk '$0 == "num-slaves" { getline; print; exit }' <<<"${master_info}")" = "2" ]
}

all_sentinels_are_ready_for_failover() {
    local sentinel

    for sentinel in "${SENTINELS[@]}"; do
        sentinel_knows_replicas "${sentinel}" || return 1
    done
}

sentinel_elected_replica() {
    local master
    master="$(sentinel_master sentinel-1)"
    [[ "${master}" =~ ^172\.30\.77\.1[23]:6379$ ]]
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

main() {
    require_docker
    trap cleanup EXIT

    compose up --detach --quiet-pull
    wait_for "the original Sentinel master" \
        test "$(sentinel_master sentinel-1)" = "${ORIGINAL_MASTER}"
    wait_for "all Sentinels to agree on the original master" \
        all_sentinels_agree_on "${ORIGINAL_MASTER}"
    wait_for "all Sentinels to discover both Redis replicas" \
        all_sentinels_are_ready_for_failover

    compose exec -T sentinel-1 redis-cli -h "${ORIGINAL_MASTER%:*}" SET \
        librenms:integration:before-failover ready >/dev/null
    compose stop redis-1

    local new_master
    wait_for "Sentinel election of a Redis replica" sentinel_elected_replica
    new_master="$(sentinel_master sentinel-1)"
    wait_for "all Sentinels to agree on the elected master" \
        all_sentinels_agree_on "${new_master}"

    local new_master_host="${new_master%:*}"
    [ "$(compose exec -T sentinel-1 redis-cli --raw -h "${new_master_host}" GET \
        librenms:integration:before-failover)" = "ready" ] || {
        printf 'The elected Redis master lost data written before failover.\n' >&2
        return 1
    }
    compose exec -T sentinel-1 redis-cli -h "${new_master_host}" SET \
        librenms:integration:after-failover ready >/dev/null

    printf 'Redis Sentinel failover test passed: elected %s after redis-1 stopped.\n' \
        "${new_master}"
}

main "$@"
