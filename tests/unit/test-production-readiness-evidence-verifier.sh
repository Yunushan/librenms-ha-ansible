#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$REPO_ROOT/roles/production_readiness/files/librenms-production-readiness-evidence-verify.py"
TEST_DIR="$(mktemp -d)"
APP_KEY="test-readiness-evidence-key-that-is-long-enough"
SOURCE_REVISION="0123456789abcdef0123456789abcdef01234567"
AUTOMATION_REVISION="fedcba9876543210fedcba9876543210fedcba98"
INVENTORY_FINGERPRINT="0000000000000000000000000000000000000000000000000000000000000000"
EVIDENCE="$TEST_DIR/production-readiness-test.json"
COMPLETED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

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
  local evidence_path="${1:-$EVIDENCE}"
  python3 - "$evidence_path" "$evidence_path.hmac" "$APP_KEY" <<'PY'
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
printf '%s\n' '{"evidence_schema_version":1,"result":"passed","completed_at":"'"$COMPLETED_AT"'","mode":"ha","vip":"10.0.0.1","source_revision":"0123456789abcdef0123456789abcdef01234567","automation_revision":"fedcba9876543210fedcba9876543210fedcba98","inventory_fingerprint":"0000000000000000000000000000000000000000000000000000000000000000","vip_tls_verified":true,"network_tcp_matrix_verified":true,"host_firewall_verified":true,"status_alert_routing_verified":true,"shared_lock_verified":true,"offsite_backup_verified":true,"database_restore_verified":true,"database_restore_elapsed_seconds":12,"database_restore_objective_seconds":60,"scheduled_daily_backup_verified":true,"runtime_web_health_verified":true,"recent_failover_evidence_verified":true,"failover_evidence_path":"/var/lib/librenms-ha/failover-evidence/example.json","failover_elapsed_seconds":30,"failover_recovery_objective_seconds":120,"database_nodes":["lnms1","lnms2","lnms3"],"redis_nodes":["lnms1","lnms2","lnms3"],"load_balancer_nodes":["lnms1","lnms2"],"application_nodes":["lnms1","lnms2","lnms3"],"web_nodes":["lnms1","lnms2"],"inactive_nodes":[]}' > "$EVIDENCE"
printf '%s  %s\n' \
  "$(sha256sum "$EVIDENCE" | awk '{print $1}')" \
  "$(basename "$EVIDENCE")" > "$EVIDENCE.sha256"
write_hmac_sidecar

python3 "$VERIFIER" --evidence "$EVIDENCE" --source-revision "$SOURCE_REVISION" \
  --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" --max-age-seconds 86400 \
  --app-env "$TEST_DIR/.env" >/dev/null
printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" \
  --max-age-seconds 86400 --app-key-stdin >/dev/null

if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --max-age-seconds 86400 --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted evidence without expected deployment identity" >&2
  exit 1
fi

STANDALONE_EVIDENCE="$TEST_DIR/production-readiness-standalone.json"
python3 - "$EVIDENCE" "$STANDALONE_EVIDENCE" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
record = json.loads(source.read_text(encoding="utf-8"))
record["mode"] = "standalone"
record.pop("vip", None)
target.write_text(json.dumps(record), encoding="utf-8")
PY
printf '%s  %s\n' \
  "$(sha256sum "$STANDALONE_EVIDENCE" | awk '{print $1}')" \
  "$(basename "$STANDALONE_EVIDENCE")" > "$STANDALONE_EVIDENCE.sha256"
write_hmac_sidecar "$STANDALONE_EVIDENCE"
printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$STANDALONE_EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" \
  --max-age-seconds 86400 --app-key-stdin >/dev/null

LINK_EVIDENCE="$TEST_DIR/production-readiness-link.json"
if ln -s "$EVIDENCE" "$LINK_EVIDENCE" 2>/dev/null && \
  ln -s "$EVIDENCE.sha256" "$LINK_EVIDENCE.sha256" 2>/dev/null; then
  if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$LINK_EVIDENCE" \
    --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
    --inventory-fingerprint "$INVENTORY_FINGERPRINT" \
    --max-age-seconds 86400 --app-key-stdin >/dev/null 2>&1; then
    echo "Verifier accepted a symlinked evidence record" >&2
    exit 1
  fi
fi

if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "fedcba9876543210fedcba9876543210fedcba98" \
  --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" --max-age-seconds 86400 \
  --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted an evidence record from an unexpected source revision" >&2
  exit 1
fi

if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" \
  --automation-revision "$SOURCE_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" --max-age-seconds 86400 \
  --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted evidence from an unexpected automation revision" >&2
  exit 1
fi

if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" \
  --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" \
  --max-age-seconds 86400 --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted an evidence record from an unexpected inventory" >&2
  exit 1
fi

python3 - "$EVIDENCE" <<'PY'
import json
import pathlib
import sys

evidence = pathlib.Path(sys.argv[1])
record = json.loads(evidence.read_text(encoding="utf-8"))
record["inactive_nodes"] = ["lnms3"]
evidence.write_text(json.dumps(record), encoding="utf-8")
PY
printf '%s  %s\n' \
  "$(sha256sum "$EVIDENCE" | awk '{print $1}')" \
  "$(basename "$EVIDENCE")" > "$EVIDENCE.sha256"
write_hmac_sidecar
if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted an inactive node in an HA evidence record" >&2
  exit 1
fi

STALE_EVIDENCE="$TEST_DIR/production-readiness-stale.json"
cp "$EVIDENCE" "$STALE_EVIDENCE"
python3 - "$STALE_EVIDENCE" <<'PY'
from datetime import datetime, timedelta, timezone
import json
import pathlib
import sys

evidence = pathlib.Path(sys.argv[1])
record = json.loads(evidence.read_text(encoding="utf-8"))
record["completed_at"] = (
    datetime.now(timezone.utc) - timedelta(days=2)
).strftime("%Y-%m-%dT%H:%M:%SZ")
evidence.write_text(json.dumps(record), encoding="utf-8")
PY
printf '%s  %s\n' \
  "$(sha256sum "$STALE_EVIDENCE" | awk '{print $1}')" \
  "$(basename "$STALE_EVIDENCE")" > "$STALE_EVIDENCE.sha256"
write_hmac_sidecar "$STALE_EVIDENCE"
if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$STALE_EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" \
  --max-age-seconds 86400 --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted stale readiness evidence" >&2
  exit 1
fi

printf '%s\n' '{"result":"failed","completed_at":"2026-01-01T00:00:00Z","mode":"ha","vip":"10.0.0.1"}' > "$EVIDENCE"
printf '%s  %s\n' \
  "$(sha256sum "$EVIDENCE" | awk '{print $1}')" \
  "$(basename "$EVIDENCE")" > "$EVIDENCE.sha256"
write_hmac_sidecar
if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted a non-passing evidence record" >&2
  exit 1
fi

printf '%s\n' '{"evidence_schema_version":99,"result":"passed","completed_at":"2026-01-01T00:00:00Z","mode":"ha","vip":"10.0.0.1"}' > "$EVIDENCE"
printf '%s  %s\n' \
  "$(sha256sum "$EVIDENCE" | awk '{print $1}')" \
  "$(basename "$EVIDENCE")" > "$EVIDENCE.sha256"
write_hmac_sidecar
if printf '%s' "$APP_KEY" | python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" --app-key-stdin >/dev/null 2>&1; then
  echo "Verifier accepted an unsupported evidence schema" >&2
  exit 1
fi

printf '%064d  %s\n' 0 "$(basename "$EVIDENCE")" > "$EVIDENCE.hmac"
if python3 "$VERIFIER" --evidence "$EVIDENCE" \
  --source-revision "$SOURCE_REVISION" --automation-revision "$AUTOMATION_REVISION" \
  --inventory-fingerprint "$INVENTORY_FINGERPRINT" \
  --app-env "$TEST_DIR/.env" >/dev/null 2>&1; then
  echo "Verifier accepted a tampered HMAC sidecar" >&2
  exit 1
fi

echo "Production readiness evidence verifier test passed."
