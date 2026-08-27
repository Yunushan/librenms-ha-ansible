#!/usr/bin/env python3
"""Verify the GitHub controls required by the production release checklist.

This is deliberately read-only. It is an operator-side check because GitHub
repository settings are outside Ansible and are not safely mutable from CI.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_CHECKS = {
    "ansible-lint",
    "controller-image",
    "haproxy-web-failover",
    "galera-failover",
    "docker-ha-galera-config",
    "redis-sentinel-failover",
    "dependency-review",
}
GH_ENV: dict[str, str] | None = None


def github_environment() -> dict[str, str]:
    """Make the authenticated gh session available to non-interactive calls."""

    global GH_ENV
    if GH_ENV is not None:
        return GH_ENV

    GH_ENV = os.environ.copy()
    if GH_ENV.get("GH_TOKEN") or GH_ENV.get("GITHUB_TOKEN"):
        return GH_ENV

    result = subprocess.run(
        ["gh", "auth", "token", "--hostname", "github.com"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(f"gh auth token failed: {detail}")
    GH_ENV["GH_TOKEN"] = token
    return GH_ENV


def run_gh_api(endpoint: str) -> dict[str, Any]:
    """Read one GitHub REST resource without exposing command credentials."""

    command = ["gh", "api", endpoint]
    result = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        if "401" not in detail and "authentication" not in detail.lower():
            raise RuntimeError(f"gh api {endpoint} failed: {detail}")
        result = subprocess.run(
            command,
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            env=github_environment(),
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
            raise RuntimeError(f"gh api {endpoint} failed: {detail}")
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"gh api {endpoint} returned invalid JSON") from exc
    if not isinstance(value, dict):
        raise RuntimeError(f"gh api {endpoint} returned a non-object response")
    return value


def remote_repository() -> str:
    result = subprocess.run(
        ["git", "config", "--get", "remote.origin.url"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    remote = result.stdout.strip()
    patterns = (
        r"^https?://github\.com/([^/]+/[^/]+?)(?:\.git)?/?$",
        r"^git@github\.com:([^/]+/[^/]+?)(?:\.git)?$",
        r"^ssh://git@github\.com/([^/]+/[^/]+?)(?:\.git)?/?$",
    )
    for pattern in patterns:
        match = re.match(pattern, remote)
        if match:
            return match.group(1)
    raise RuntimeError(
        "Could not determine a GitHub owner/repository from remote.origin.url; "
        "pass --repo OWNER/REPOSITORY explicitly."
    )


def enabled(value: Any) -> bool:
    return isinstance(value, dict) and value.get("enabled") is True


def status_enabled(value: Any) -> bool:
    return isinstance(value, dict) and value.get("status") == "enabled"


def explicitly_disabled(value: Any) -> bool:
    return isinstance(value, dict) and value.get("enabled") is False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify production-required GitHub repository governance."
    )
    parser.add_argument("--repo", help="GitHub repository in OWNER/REPOSITORY form")
    parser.add_argument("--branch", default="main", help="Protected branch (default: main)")
    args = parser.parse_args()

    try:
        repo = args.repo or remote_repository()
        repository = run_gh_api(f"repos/{repo}")
        protection = run_gh_api(f"repos/{repo}/branches/{args.branch}/protection")
        vulnerability_reporting = run_gh_api(
            f"repos/{repo}/private-vulnerability-reporting"
        )
    except (OSError, RuntimeError) as exc:
        print(f"GitHub governance check failed: {exc}", file=sys.stderr)
        return 2

    failures: list[str] = []
    codeowners = ROOT / ".github" / "CODEOWNERS"
    codeowners_text = codeowners.read_text(encoding="utf-8") if codeowners.is_file() else ""
    codeowners_ok = bool(
        re.search(
            r"(?m)^\s*\*\s+@[A-Za-z0-9-]+(?:\s+@[A-Za-z0-9-]+)*\s*$",
            codeowners_text,
        )
    )
    if not codeowners_ok:
        failures.append(".github/CODEOWNERS must assign an explicit repository-wide owner")

    required_status_checks = protection.get("required_status_checks")
    configured_checks: set[str] = set()
    if not isinstance(required_status_checks, dict):
        failures.append("main must require status checks")
    else:
        if required_status_checks.get("strict") is not True:
            failures.append("main required status checks must require the branch to be up to date")
        configured_checks = {
            check.get("context")
            for check in required_status_checks.get("checks", [])
            if isinstance(check, dict) and isinstance(check.get("context"), str)
        }
        configured_checks.update(
            context
            for context in required_status_checks.get("contexts", [])
            if isinstance(context, str)
        )
        missing_checks = sorted(REQUIRED_CHECKS - configured_checks)
        if missing_checks:
            failures.append("main is missing required checks: " + ", ".join(missing_checks))

    if not enabled(protection.get("enforce_admins")):
        failures.append("administrator enforcement must be enabled")

    reviews = protection.get("required_pull_request_reviews")
    if not isinstance(reviews, dict):
        failures.append("main must require pull-request approval")
    else:
        try:
            approving_review_count = int(reviews.get("required_approving_review_count", 0))
        except (TypeError, ValueError):
            approving_review_count = 0
        if approving_review_count < 1:
            failures.append("main must require at least one approving review")
        if reviews.get("require_code_owner_reviews") is not True:
            failures.append("main must require code-owner review")
        if reviews.get("dismiss_stale_reviews") is not True:
            failures.append("main must dismiss stale approvals after new commits")

    if not enabled(protection.get("required_conversation_resolution")):
        failures.append("main must require resolved review conversations")
    if not enabled(protection.get("required_linear_history")):
        failures.append("main must require linear history")
    if not explicitly_disabled(protection.get("allow_force_pushes")):
        failures.append("main must disallow force pushes")
    if not explicitly_disabled(protection.get("allow_deletions")):
        failures.append("main must disallow branch deletion")

    security = repository.get("security_and_analysis")
    if not isinstance(security, dict):
        failures.append("repository security settings were not returned by GitHub")
    else:
        for key, label in (
            ("dependabot_security_updates", "Dependabot security updates"),
            ("secret_scanning", "secret scanning"),
            ("secret_scanning_push_protection", "secret-scanning push protection"),
        ):
            if not status_enabled(security.get(key)):
                failures.append(f"{label} must be enabled")

    if vulnerability_reporting.get("enabled") is not True:
        failures.append("GitHub private vulnerability reporting must be enabled")

    print(f"Repository: {repo}")
    print(f"Protected branch: {args.branch}")
    print(
        "Configured required checks: "
        f"{len(REQUIRED_CHECKS & configured_checks)}/{len(REQUIRED_CHECKS)}"
    )
    print(f"Repository-wide CODEOWNERS: {'yes' if codeowners_ok else 'no'}")
    print(
        "Private vulnerability reporting: "
        f"{'yes' if vulnerability_reporting.get('enabled') is True else 'no'}"
    )

    if failures:
        print("GitHub governance checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("GitHub governance checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
