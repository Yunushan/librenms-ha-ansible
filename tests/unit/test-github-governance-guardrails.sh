#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly GOVERNANCE_SCRIPT="${ROOT_DIR}/scripts/ci-github-governance-check.py"
readonly SAFETY_SCRIPT="${ROOT_DIR}/scripts/ci-production-safety-check.py"
readonly MAKEFILE="${ROOT_DIR}/Makefile"
readonly LINT_WORKFLOW="${ROOT_DIR}/.github/workflows/lint.yml"

fail() {
    printf 'GitHub governance guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "$expected" "$file" || \
        fail "missing ${expected} in ${file}"
}

require_text "$GOVERNANCE_SCRIPT" \
    'f"repos/{repo}/dependabot/alerts?state=open&per_page=1"'
require_text "$GOVERNANCE_SCRIPT" 'allow_list=True'
require_text "$GOVERNANCE_SCRIPT" 'repository must have no open Dependabot alerts'
require_text "$GOVERNANCE_SCRIPT" \
    'f"repos/{repo}/code-scanning/default-setup"'
require_text "$GOVERNANCE_SCRIPT" \
    'codeql_default_setup.get("state") != "configured"'
require_text "$GOVERNANCE_SCRIPT" 'CodeQL default setup: '

require_text "$SAFETY_SCRIPT" \
    'dependabot/alerts?state=open&per_page=1'
require_text "$SAFETY_SCRIPT" 'code-scanning/default-setup'

require_text "$MAKEFILE" 'test-github-governance-guardrails:'
require_text "$MAKEFILE" 'test-fast-repair-guardrails test-github-governance-guardrails'
require_text "$LINT_WORKFLOW" \
    'run: make test-github-governance-guardrails'

printf 'GitHub governance guardrail test passed.\n'
