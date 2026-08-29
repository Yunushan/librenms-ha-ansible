#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CHART_DIR="${ROOT_DIR}/charts/librenms-ha"
readonly PRODUCTION_VALUES="${ROOT_DIR}/examples/kubernetes/values-production.yaml.example"

fail() {
    printf 'Helm chart test failed: %s\n' "$1" >&2
    exit 1
}

require_output() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "$expected" "$file" ||
        fail "expected ${expected} in ${file}"
}

main() {
    command -v helm >/dev/null 2>&1 || fail 'helm is required'
    [ -d "$CHART_DIR" ] || fail "missing chart directory: $CHART_DIR"
    [ -f "$CHART_DIR/values.schema.json" ] || fail "missing chart values schema"
    [ -f "$PRODUCTION_VALUES" ] || fail "missing production values: $PRODUCTION_VALUES"

    helm lint "$CHART_DIR" --values "$PRODUCTION_VALUES"

    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf -- "${temp_dir:-}"' EXIT

    helm template librenms "$CHART_DIR" \
        --namespace librenms \
        --values "$PRODUCTION_VALUES" \
        >"${temp_dir}/rendered.yaml"
    require_output "${temp_dir}/rendered.yaml" 'kind: Deployment'
    require_output "${temp_dir}/rendered.yaml" 'kind: StatefulSet'
    require_output "${temp_dir}/rendered.yaml" 'kind: NetworkPolicy'
    require_output "${temp_dir}/rendered.yaml" 'type: RuntimeDefault'
    require_output "${temp_dir}/rendered.yaml" 'allowPrivilegeEscalation: false'

    if helm template librenms "$CHART_DIR" \
        --namespace librenms \
        --values "$PRODUCTION_VALUES" \
        --set-string persistence.existingClaim= \
        >"${temp_dir}/invalid.yaml" 2>"${temp_dir}/invalid.err"; then
        fail 'production chart rendered without a shared persistence claim'
    fi
    require_output "${temp_dir}/invalid.err" \
        'production requires persistence.existingClaim'

    printf 'Helm chart test passed.\n'
}

main "$@"
