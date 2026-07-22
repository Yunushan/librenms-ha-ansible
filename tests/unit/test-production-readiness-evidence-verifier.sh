#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$REPO_ROOT/roles/production_readiness/files/librenms-production-readiness-evidence-verify.py"
TEST_DIR="$(mktemp -d)"
APP_KEY="test-readiness-evidence-key-that-is-long-enough"
EVIDENCE="$TEST_DIR/production-readiness-test.json"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

write_hmac_sidecar() {
  python3 - "$EVIDENCE" "$EVIDENCE.hmac" "$APP_KEY" <<'PY'
import hashlib
import hmac
import pathlib
import sys

evidence = pathlib.Path(sys.argv[1])
sidecar = pathlib.Path(sys.argv[2])
key = sys.argv[3].encode("utf-8")
digest = hmac.new(key, evidence.read_bytes(), hashlib.sha256).hexdigest()
sidecar.write_text(f"{digest}  {evidence.name}\n", encoding="utf-8")
PY
}

require_file "$VERIFIER"
printf '%s\n' "APP_KEY=$APP_KEY" > "$TEST_DIR/.env"
printf '%s\n' '{"result":"passed"}' > "$EVIDENCE"
sha256sum "$EVIDENCE" | sed "s#  $EVIDENCE#  $(basename "$EVIDENCE")#" > "$EVIDENCE.sha256"
write_hmac_sidecar

python3 "$VERIFIER" --evidence "$EVIDENCE" --app-env "$TEST_DIR/.env" >/dev/null

printf '%064d  %s\n' 0 "$(basename "$EVIDENCE")" > "$EVIDENCE.hmac"
if python3 "$VERIFIER" --evidence "$EVIDENCE" --app-env "$TEST_DIR/.env" >/dev/null 2>&1; then
  echo "Verifier accepted a tampered HMAC sidecar" >&2
  exit 1
fi

echo "Production readiness evidence verifier test passed."
