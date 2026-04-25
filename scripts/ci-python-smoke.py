#!/usr/bin/env python3
"""Run Python-only repository smoke checks.

This intentionally avoids ansible-playbook, yamllint, and ansible-lint so it can
run directly from Windows, WSL, Linux, or a minimal CI image with Python and the
project Python dependencies installed.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_check(name: str, args: list[str]) -> int:
    print(f"\n==> {name}", flush=True)
    result = subprocess.run(args, cwd=ROOT, check=False)  # noqa: S603
    if result.returncode == 0:
        print(f"OK: {name}", flush=True)
    else:
        print(
            f"FAIL: {name} exited with {result.returncode}",
            file=sys.stderr,
            flush=True,
        )
    return result.returncode


def main() -> int:
    python = sys.executable
    checks = [
        (
            "Parse YAML files",
            [python, "scripts/ci-parse-yaml.py"],
        ),
        (
            "Check Markdown links",
            [python, "scripts/ci-check-markdown-links.py"],
        ),
        (
            "Validate HA sample inventory",
            [
                python,
                "scripts/validate-inventory.py",
                "--inventory",
                "inventories/ha/hosts.yml",
                "--group-vars",
                "inventories/ha/group_vars/all.yml",
                "--allow-placeholders",
            ],
        ),
        (
            "Validate standalone sample inventory",
            [
                python,
                "scripts/validate-inventory.py",
                "--inventory",
                "inventories/standalone/hosts.yml",
                "--group-vars",
                "inventories/standalone/group_vars/all.yml",
                "--allow-placeholders",
            ],
        ),
        (
            "Compile Python helper scripts",
            [
                python,
                "-m",
                "py_compile",
                "scripts/ci-ansible-syntax-check.py",
                "scripts/ci-check-markdown-links.py",
                "scripts/ci-parse-yaml.py",
                "scripts/ci-python-smoke.py",
                "scripts/validate-inventory.py",
            ],
        ),
    ]

    failures = 0
    for name, args in checks:
        if run_check(name, args) != 0:
            failures += 1

    if failures:
        print(f"\nPython smoke checks failed: {failures}", file=sys.stderr, flush=True)
        return 1

    print("\nPython smoke checks passed.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
