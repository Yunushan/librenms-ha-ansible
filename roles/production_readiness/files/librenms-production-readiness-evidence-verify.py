#!/usr/bin/env python3
"""Verify a production-readiness evidence record without exposing its app key."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import re
import sys
from pathlib import Path


SIDECAR_PATTERN = re.compile(r"([a-f0-9]{64})  ([^/]+)")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


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
        if len(key) > 20 and "CHANGE_ME" not in key:
            return key
        fail("application APP_KEY is missing, a placeholder, or too short")

    fail("application environment file does not define APP_KEY")
    return ""


def digest(path: Path) -> str:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        fail(f"cannot read evidence record {path}: {error}")
    return ""


def read_sidecar(path: Path, expected_name: str, label: str) -> str:
    try:
        value = path.read_text(encoding="utf-8").rstrip("\n")
    except OSError as error:
        fail(f"cannot read {label} sidecar {path}: {error}")

    match = SIDECAR_PATTERN.fullmatch(value)
    if not match or match.group(2) != expected_name:
        fail(f"{label} sidecar has an invalid format or filename")
    return match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify LibreNMS production-readiness evidence integrity."
    )
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--app-env", default="/opt/librenms/.env", type=Path)
    args = parser.parse_args()

    evidence = args.evidence
    if evidence.suffix != ".json":
        fail("evidence must be a .json record")

    sha_digest = read_sidecar(evidence.with_suffix(".json.sha256"), evidence.name, "SHA-256")
    actual_digest = digest(evidence)
    if not hmac.compare_digest(sha_digest, actual_digest):
        fail("SHA-256 sidecar does not match the evidence record")

    hmac_digest = read_sidecar(evidence.with_suffix(".json.hmac"), evidence.name, "HMAC")
    app_key = app_key_from_env(args.app_env)
    expected_hmac = hmac.new(
        app_key.encode("utf-8"), evidence.read_bytes(), hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(hmac_digest, expected_hmac):
        fail("HMAC sidecar does not match the evidence record")

    print(f"Evidence integrity verified: {evidence.name}")


if __name__ == "__main__":
    main()
