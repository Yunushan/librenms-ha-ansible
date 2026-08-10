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
contains 'librenms_redis_sentinel_consensus_initial_ok'
contains 'librenms_redis_sentinel_consensus_needs_repair'
contains 'Repair Redis Sentinel consensus master after failed quorum or write check'
contains 'Fail when Redis Sentinel cannot converge on a writable quorum'

if sed -n '/^- name: Determine Redis Sentinel consensus master/,/^- name: Set Redis Sentinel consensus endpoint/p' \
    "${TASKS_FILE}" | grep -Fq '^- name: Verify Redis Sentinels agree on one master'; then
    fail 'initial Sentinel disagreement still aborts before automatic repair'
fi

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
grep -Fq 'librenms_redis_sentinel_consensus_controller_candidates' <<< "${consensus_block}" \
    || fail 'consensus controller selection is not separated from the query set'
grep -Fq 'intersect(ansible_play_hosts_all | default([]))' <<< "${consensus_block}" \
    || fail 'controller selection does not prefer a host participating in the current play'

if sed -n '/librenms_redis_sentinel_consensus_query_nodes:/,/librenms_redis_sentinel_consensus_controller_candidates:/p' \
    <<< "${consensus_block}" | grep -Fq 'intersect(ansible_play_hosts_all'; then
    fail 'consensus query nodes still depend on the reduced active play host set'
fi

printf 'Redis Sentinel consensus guardrail test passed.\n'
