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

contains "groups.get('librenms_redis', [])"
contains 'librenms_redis_sentinel_consensus_controller_host'
contains 'Validate Redis Sentinel consensus query node quorum'
contains 'librenms_redis_sentinel_consensus_queries.rc'
contains 'librenms_redis_sentinel_consensus_retries'
contains 'librenms_redis_sentinel_consensus_delay'

if sed -n '/^- name: Determine Redis Sentinel consensus query nodes/,/^- name: Confirm Redis Sentinel consensus writable master/p' "${TASKS_FILE}" \
    | grep -Fq 'librenms_active_redis_nodes'; then
    fail 'consensus still depends on the serial-batch active-node fact'
fi

consensus_block=$(sed -n \
    '/^- name: Determine Redis Sentinel consensus query nodes/,/^- name: Validate Redis Sentinel consensus query node quorum/p' \
    "${TASKS_FILE}")

grep -Fq "groups.get('librenms_redis', [])" <<< "${consensus_block}" \
    || fail 'consensus query nodes do not use the full Redis inventory group'
grep -Fq 'difference(librenms_inactive_inventory_nodes | default([]))' \
    <<< "${consensus_block}" \
    || fail 'consensus query nodes do not exclude only explicit inactive hosts'

printf 'Redis Sentinel consensus guardrail test passed.\n'
