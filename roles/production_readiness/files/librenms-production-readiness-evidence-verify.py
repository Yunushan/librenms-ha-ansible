#!/usr/bin/env python3
"""Verify a production-readiness evidence record without exposing its app key."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import hmac
import json
import re
import stat
import sys
from pathlib import Path


SIDECAR_PATTERN = re.compile(r"([a-f0-9]{64})  ([^/]+)")
EVIDENCE_SCHEMA_VERSION = 1
HA_REQUIRED_BOOLEAN_FIELDS = (
    "vip_tls_verified",
    "network_tcp_matrix_verified",
    "host_firewall_verified",
    "status_alert_routing_verified",
    "shared_lock_verified",
    "offsite_backup_verified",
    "database_restore_verified",
    "scheduled_daily_backup_verified",
    "runtime_web_health_verified",
    "recent_failover_evidence_verified",
)
HA_REQUIRED_NODE_LISTS = {
    "database_nodes": 3,
    "redis_nodes": 3,
    "load_balancer_nodes": 2,
    "web_nodes": 2,
    "inactive_nodes": 0,
}
DURATION_FIELDS = (
    "database_restore_elapsed_seconds",
    "database_restore_objective_seconds",
    "failover_elapsed_seconds",
    "failover_recovery_objective_seconds",
)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_app_key(key: str, source: str) -> str:
    if len(key) > 20 and "CHANGE_ME" not in key:
        return key
    fail(f"application APP_KEY from {source} is missing, a placeholder, or too short")
    return ""


def app_key_from_env(path: Path) -> str:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        fail(f"cannot read application environment file {path}: {error}")

    for line in lines:
        if not line.startswith("APP_KEY="):
            continue
        key = line.partition("=")[2].strip()
        if len(key) >= 2 and key[0] == key[-1] and key[0] in {"'", '"'}:
            key = key[1:-1]
        return validate_app_key(key, str(path))

    fail("application environment file does not define APP_KEY")
    return ""


def app_key_from_stdin() -> str:
    return validate_app_key(sys.stdin.read().strip(), "standard input")


def digest(path: Path) -> str:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        fail(f"cannot read evidence record {path}: {error}")
    return ""


def require_regular_file(path: Path, label: str) -> None:
    try:
        mode = path.lstat().st_mode
    except OSError as error:
        fail(f"cannot inspect {label} {path}: {error}")
    if not stat.S_ISREG(mode):
        fail(f"{label} must be a regular file and not a symlink or special file: {path}")


def read_sidecar(path: Path, expected_name: str, label: str) -> str:
    require_regular_file(path, f"{label} sidecar")
    try:
        value = path.read_text(encoding="utf-8").rstrip("\n")
    except OSError as error:
        fail(f"cannot read {label} sidecar {path}: {error}")

    match = SIDECAR_PATTERN.fullmatch(value)
    if not match or match.group(2) != expected_name:
        fail(f"{label} sidecar has an invalid format or filename")
    return match.group(1)


def require_nonempty_string(record: dict[str, object], field: str) -> str:
    value = record.get(field)
    if not isinstance(value, str) or not value.strip():
        fail(f"evidence record field {field} must be a non-empty string")
    return value.strip()


def parse_completed_at(record: dict[str, object]) -> datetime:
    completed_at = require_nonempty_string(record, "completed_at")
    try:
        parsed = datetime.fromisoformat(completed_at.replace("Z", "+00:00"))
    except ValueError:
        fail("evidence record completed_at must be an ISO-8601 timestamp")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        fail("evidence record completed_at must include a timezone")
    return parsed.astimezone(timezone.utc)


def require_fresh_evidence(record: dict[str, object], max_age_seconds: int) -> None:
    if max_age_seconds < 1:
        fail("maximum evidence age must be a positive number of seconds")

    age_seconds = (datetime.now(timezone.utc) - parse_completed_at(record)).total_seconds()
    if age_seconds < 0:
        fail("evidence record completed_at is in the future")
    if age_seconds > max_age_seconds:
        fail(
            "evidence record is too old: "
            f"{int(age_seconds)} seconds exceeds the {max_age_seconds}-second limit"
        )


def require_true_boolean(record: dict[str, object], field: str) -> None:
    if type(record.get(field)) is not bool or record[field] is not True:
        fail(f"evidence record field {field} must be true for an HA certification")


def require_node_list(record: dict[str, object], field: str, minimum: int) -> None:
    value = record.get(field)
    if not isinstance(value, list) or len(value) < minimum:
        fail(f"evidence record field {field} must list at least {minimum} nodes")
    if any(not isinstance(node, str) or not node.strip() for node in value):
        fail(f"evidence record field {field} contains an invalid node name")
    if len(set(value)) != len(value):
        fail(f"evidence record field {field} contains duplicate node names")


def require_nonnegative_number(record: dict[str, object], field: str) -> float:
    value = record.get(field)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
        fail(f"evidence record field {field} must be a non-negative number")
    return float(value)


def validate_evidence_record(path: Path) -> dict[str, object]:
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"evidence record is not valid JSON: {error}")

    if not isinstance(record, dict):
        fail("evidence record must be a JSON object")
    if record.get("result") != "passed":
        fail("evidence record is not a passing readiness result")

    if record.get("evidence_schema_version") != EVIDENCE_SCHEMA_VERSION:
        fail(
            "evidence record has an unsupported or missing schema version "
            f"(expected {EVIDENCE_SCHEMA_VERSION})"
        )
    parse_completed_at(record)
    mode = require_nonempty_string(record, "mode")
    require_nonempty_string(record, "vip")
    source_revision = require_nonempty_string(record, "source_revision")
    automation_revision = require_nonempty_string(record, "automation_revision")
    inventory_fingerprint = require_nonempty_string(record, "inventory_fingerprint")
    if not re.fullmatch(r"[0-9a-f]{40}", source_revision):
        fail("evidence record source_revision is not a 40-character Git SHA")
    if not re.fullmatch(r"[0-9a-f]{40}", automation_revision):
        fail("evidence record automation_revision is not a 40-character Git SHA")
    if not re.fullmatch(r"[0-9a-f]{64}", inventory_fingerprint):
        fail("evidence record inventory_fingerprint is not a SHA-256 digest")
    if mode not in {"ha", "standalone"}:
        fail("evidence record mode must be ha or standalone")

    if mode == "ha":
        for field in HA_REQUIRED_BOOLEAN_FIELDS:
            require_true_boolean(record, field)
        for field, minimum in HA_REQUIRED_NODE_LISTS.items():
            require_node_list(record, field, minimum)
        if record["inactive_nodes"]:
            fail("evidence record field inactive_nodes must be empty for an HA certification")
        evidence_path = require_nonempty_string(record, "failover_evidence_path")
        if not evidence_path.startswith("/"):
            fail("evidence record failover_evidence_path must be absolute")
        durations = {
            field: require_nonnegative_number(record, field)
            for field in DURATION_FIELDS
        }
        if durations["database_restore_elapsed_seconds"] > durations[
            "database_restore_objective_seconds"
        ]:
            fail("database restore duration exceeds its recorded objective")
        if durations["failover_elapsed_seconds"] > durations[
            "failover_recovery_objective_seconds"
        ]:
            fail("failover duration exceeds its recorded objective")

    return record


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify LibreNMS production-readiness evidence integrity."
    )
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument(
        "--source-revision",
        help="Require the evidence to match this exact 40-character Git SHA.",
    )
    parser.add_argument(
        "--automation-revision",
        help="Require the evidence to match this exact automation Git SHA.",
    )
    parser.add_argument(
        "--inventory-fingerprint",
        help="Require the evidence to match this exact inventory SHA-256 digest.",
    )
    parser.add_argument(
        "--max-age-seconds",
        default=86400,
        type=int,
        help="Reject evidence older than this many seconds (default: 86400).",
    )
    key_source = parser.add_mutually_exclusive_group()
    key_source.add_argument(
        "--app-env", default=Path("/opt/librenms/.env"), type=Path
    )
    key_source.add_argument("--app-key-stdin", action="store_true")
    args = parser.parse_args()

    evidence = args.evidence
    if evidence.suffix != ".json":
        fail("evidence must be a .json record")
    require_regular_file(evidence, "evidence record")

    sha_digest = read_sidecar(
        evidence.with_suffix(".json.sha256"), evidence.name, "SHA-256"
    )
    actual_digest = digest(evidence)
    if not hmac.compare_digest(sha_digest, actual_digest):
        fail("SHA-256 sidecar does not match the evidence record")

    record = validate_evidence_record(evidence)
    require_fresh_evidence(record, args.max_age_seconds)
    if args.source_revision:
        if not re.fullmatch(r"[0-9a-f]{40}", args.source_revision):
            fail("--source-revision is not a 40-character Git SHA")
        if record["source_revision"] != args.source_revision:
            fail("evidence record source_revision does not match the expected revision")
    if args.automation_revision:
        if not re.fullmatch(r"[0-9a-f]{40}", args.automation_revision):
            fail("--automation-revision is not a 40-character Git SHA")
        if record["automation_revision"] != args.automation_revision:
            fail(
                "evidence record automation_revision does not match the expected revision"
            )
    if args.inventory_fingerprint:
        if not re.fullmatch(r"[0-9a-f]{64}", args.inventory_fingerprint):
            fail("--inventory-fingerprint is not a SHA-256 digest")
        if record["inventory_fingerprint"] != args.inventory_fingerprint:
            fail(
                "evidence record inventory_fingerprint does not match the expected inventory"
            )

    hmac_digest = read_sidecar(evidence.with_suffix(".json.hmac"), evidence.name, "HMAC")
    app_key = (
        app_key_from_stdin()
        if args.app_key_stdin
        else app_key_from_env(args.app_env)
    )
    expected_hmac = hmac.new(
        app_key.encode("utf-8"), evidence.read_bytes(), hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(hmac_digest, expected_hmac):
        fail("HMAC sidecar does not match the evidence record")

    print(f"Evidence integrity verified: {evidence.name}")


if __name__ == "__main__":
    main()
