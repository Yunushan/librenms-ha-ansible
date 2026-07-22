#!/usr/bin/env bash
set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="${TEST_DIR}/compose.yml"
readonly PROJECT_NAME="librenms-haproxy-web-integration"
readonly TIMEOUT_SECONDS="${HAPROXY_WEB_TEST_TIMEOUT_SECONDS:-60}"
export HAPROXY_WEB_TEST_PORT="${HAPROXY_WEB_TEST_PORT:-18080}"
readonly APPLICATION_URL="http://127.0.0.1:${HAPROXY_WEB_TEST_PORT}/application"

compose() {
    docker compose --project-name "${PROJECT_NAME}" --file "${COMPOSE_FILE}" "$@"
}

cleanup() {
    local exit_status=$?

    if [ "${exit_status}" -ne 0 ]; then
        printf 'HAProxy integration test failed; container diagnostics follow.\n' >&2
        compose ps >&2 || true
        compose logs --no-color >&2 || true
    fi

    compose down --volumes --remove-orphans >/dev/null 2>&1 || true
    return "${exit_status}"
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

backend_from_response() {
    curl --fail --silent --show-error --max-time 2 --dump-header - \
        --output /dev/null "${APPLICATION_URL}" |
        awk 'tolower($1) == "x-backend:" { backend=$2 } END { print backend }' |
        tr -d '\r'
}

wait_for_backend() {
    local expected="$1"
    local deadline=$((SECONDS + TIMEOUT_SECONDS))
    local backend

    until backend="$(backend_from_response 2>/dev/null)" && [ "${backend}" = "${expected}" ]; do
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            printf 'Timed out waiting for HAProxy to serve %s after runtime health failed.\n' \
                "${expected}" >&2
            return 1
        fi
        sleep 1
    done
}

main() {
    require_docker
    trap cleanup EXIT

    compose up --detach --quiet-pull

    local initial_backend
    local surviving_backend
    local response_backend
    local deadline=$((SECONDS + TIMEOUT_SECONDS))

    until initial_backend="$(backend_from_response 2>/dev/null)" && \
        [[ "${initial_backend}" =~ ^web-[12]$ ]]; do
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            printf 'Timed out waiting for HAProxy runtime health checks to become ready.\n' >&2
            return 1
        fi
        sleep 1
    done

    if [ "${initial_backend}" = "web-1" ]; then
        surviving_backend="web-2"
    else
        surviving_backend="web-1"
    fi

    compose exec --no-TTY "${initial_backend}" sh -c 'touch /tmp/runtime-unhealthy'

    compose exec --no-TTY "${initial_backend}" sh -c 'wget -qO- http://127.0.0.1/application' |
        grep -Fx 'application-ok' >/dev/null

    wait_for_backend "${surviving_backend}"

    for _ in 1 2 3; do
        response_backend="$(backend_from_response)"
        [ "${response_backend}" = "${surviving_backend}" ]
    done

    printf 'HAProxy web failover test passed: %s served after %s runtime health failed.\n' \
        "${surviving_backend}" "${initial_backend}"
}

main "$@"
