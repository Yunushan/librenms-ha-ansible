#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TASKS_FILE="${ROOT_DIR}/roles/redis_sentinel/tasks/main.yml"

fail() {
    printf 'Redis Sentinel consensus guardrail test failed: %s\n' "$1" >&2
    exit 1
}

contains() {
    local text="$1"
    grep -Fq -- "${text}" "${TASKS_FILE}" || fail "missing: ${text}"
}

contains 'librenms_active_redis_nodes'
contains 'Validate Redis Sentinel consensus query node quorum'
contains 'librenms_redis_sentinel_consensus_queries.rc'
contains 'librenms_redis_sentinel_consensus_retries'
contains 'librenms_redis_sentinel_consensus_delay'

printf 'Redis Sentinel consensus guardrail test passed.\n'
