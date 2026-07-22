#!/usr/bin/env python3
"""Fail CI when obvious credentials or private keys enter tracked source files."""

from __future__ import annotations

import re
import sys
from os import walk
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".cfg",
    ".conf",
    ".env",
    ".ini",
    ".j2",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".txt",
    ".yaml",
    ".yml",
}
IGNORED_PARTS = {
    ".git",
    "__pycache__",
    ".venv",
    "bin",
    "include",
    "lib",
    "lib64",
    "vendor",
}
PLACEHOLDER_MARKERS = (
    "CHANGE_ME",
    "example",
    "placeholder",
    "replace_me",
    "your_",
    "<",
    "{{",
    "${",
)
PRIVATE_KEY_PATTERN = re.compile(
    r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----",
)
TOKEN_PATTERNS = {
    "AWS access key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "GitHub personal token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    "GitLab personal token": re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}\b"),
    "Slack token": re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
}
SENSITIVE_ASSIGNMENT = re.compile(
    r"^\s*"
    r"(?:librenms_app_key|librenms_db_password|librenms_redis_password|"
    r"librenms_redis_sentinel_password|librenms_keepalived_auth_pass|"
    r"librenms_initial_admin_password)\s*[:=]\s*(?P<value>.+?)\s*$",
    re.IGNORECASE,
)


def is_text_candidate(path: Path) -> bool:
    return path.suffix.lower() in TEXT_SUFFIXES or path.name in {"Dockerfile", "Makefile"}


def is_placeholder(value: str) -> bool:
    normalized = value.strip().strip("\"'")
    if not normalized:
        return True
    lowered = normalized.lower()
    return any(marker.lower() in lowered for marker in PLACEHOLDER_MARKERS)


def scan_file(path: Path) -> list[str]:
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []

    findings: list[str] = []
    relative = path.relative_to(ROOT)
    if PRIVATE_KEY_PATTERN.search(content):
        findings.append(f"{relative}: committed private-key material")

    for label, pattern in TOKEN_PATTERNS.items():
        if pattern.search(content):
            findings.append(f"{relative}: possible {label}")

    for line_number, line in enumerate(content.splitlines(), start=1):
        match = SENSITIVE_ASSIGNMENT.match(line)
        if match and not is_placeholder(match.group("value")):
            findings.append(
                f"{relative}:{line_number}: non-placeholder LibreNMS secret assignment",
            )

    return findings


def main() -> int:
    findings: list[str] = []
    for root, directories, filenames in walk(ROOT):
        directories[:] = [
            directory for directory in directories if directory not in IGNORED_PARTS
        ]
        for filename in filenames:
            path = Path(root, filename)
            if is_text_candidate(path):
                findings.extend(scan_file(path))

    if findings:
        print("Secret scan failed:", file=sys.stderr)
        print("\n".join(f"- {finding}" for finding in findings), file=sys.stderr)
        return 1

    print("Secret scan passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
