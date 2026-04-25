#!/usr/bin/env python3
"""Check local Markdown links and anchors.

The check is intentionally dependency-free for CI and controller portability. It
validates repository-local Markdown links, local file targets, and GitHub-style
heading anchors. External URLs are ignored.
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.parse
from collections import Counter
from pathlib import Path


DEFAULT_EXCLUDE_DIRS = {
    ".ansible",
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    "__pycache__",
    "diagnostics",
}

MARKDOWN_LINK_RE = re.compile(r"!?\[[^\]]*]\(([^)\n]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
EXTERNAL_SCHEMES = {
    "http",
    "https",
    "mailto",
    "tel",
}


def should_skip(path: Path, exclude_dirs: set[str]) -> bool:
    return any(part in exclude_dirs for part in path.parts)


def iter_markdown_files(root: Path, exclude_dirs: set[str]) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*.md")
        if path.is_file() and not should_skip(path.relative_to(root), exclude_dirs)
    )


def strip_code_fences(text: str) -> str:
    lines: list[str] = []
    in_fence = False
    fence_marker = ""

    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith(("```", "~~~")):
            marker = stripped[:3]
            if not in_fence:
                in_fence = True
                fence_marker = marker
            elif marker == fence_marker:
                in_fence = False
                fence_marker = ""
            lines.append("")
            continue

        lines.append("" if in_fence else line)

    return "\n".join(lines)


def markdown_heading_slug(text: str) -> str:
    text = re.sub(r"\s+#+\s*$", "", text.strip())
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"!\[([^\]]*)]\([^)]*\)", r"\1", text)
    text = re.sub(r"\[([^\]]*)]\([^)]*\)", r"\1", text)
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    text = re.sub(r"\s+", "-", text.strip())
    text = re.sub(r"-+", "-", text)
    return text


def heading_anchors(text: str) -> set[str]:
    anchors: set[str] = set()
    seen: Counter[str] = Counter()

    for line in strip_code_fences(text).splitlines():
        match = HEADING_RE.match(line)
        if not match:
            continue

        base_slug = markdown_heading_slug(match.group(2))
        slug = base_slug
        if seen[base_slug] > 0:
            slug = f"{base_slug}-{seen[base_slug]}"
        seen[base_slug] += 1
        anchors.add(slug)

    return anchors


def parse_link_target(raw_target: str) -> str:
    raw_target = raw_target.strip()
    if raw_target.startswith("<") and ">" in raw_target:
        return raw_target[1 : raw_target.index(">")]
    return raw_target.split()[0]


def is_external_target(target: str) -> bool:
    parsed = urllib.parse.urlsplit(target)
    return parsed.scheme.lower() in EXTERNAL_SCHEMES


def resolve_repo_path(root: Path, source: Path, link_path: str) -> Path:
    decoded = urllib.parse.unquote(link_path)
    if decoded.startswith("/"):
        candidate = root / decoded.lstrip("/")
    else:
        candidate = source.parent / decoded
    return candidate.resolve()


def validate_anchor(
    root: Path,
    source: Path,
    target_file: Path,
    fragment: str,
    anchor_cache: dict[Path, set[str]],
) -> str | None:
    anchor = urllib.parse.unquote(fragment).lower()
    if not anchor:
        return None

    if target_file.suffix.lower() != ".md":
        return None

    if target_file not in anchor_cache:
        anchor_cache[target_file] = heading_anchors(target_file.read_text(encoding="utf-8"))

    if anchor not in anchor_cache[target_file]:
        return (
            f"{source.relative_to(root)}: missing anchor #{anchor} "
            f"in {target_file.relative_to(root)}"
        )

    return None


def validate_markdown_file(
    root: Path,
    path: Path,
    anchor_cache: dict[Path, set[str]],
) -> list[str]:
    failures: list[str] = []
    text = path.read_text(encoding="utf-8")
    searchable = strip_code_fences(text)

    for match in MARKDOWN_LINK_RE.finditer(searchable):
        target = parse_link_target(match.group(1))
        if not target or is_external_target(target):
            continue

        parsed = urllib.parse.urlsplit(target)
        if parsed.scheme:
            continue

        link_path = parsed.path
        fragment = parsed.fragment

        if not link_path:
            failure = validate_anchor(root, path, path, fragment, anchor_cache)
            if failure:
                failures.append(failure)
            continue

        target_file = resolve_repo_path(root, path, link_path)
        try:
            target_file.relative_to(root)
        except ValueError:
            failures.append(f"{path.relative_to(root)}: link escapes repository: {target}")
            continue

        if not target_file.exists():
            failures.append(f"{path.relative_to(root)}: missing link target: {target}")
            continue

        failure = validate_anchor(root, path, target_file, fragment, anchor_cache)
        if failure:
            failures.append(failure)

    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", type=Path)
    parser.add_argument(
        "--exclude-dir",
        action="append",
        default=[],
        help="directory name to exclude; can be specified more than once",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    exclude_dirs = DEFAULT_EXCLUDE_DIRS | set(args.exclude_dir)
    anchor_cache: dict[Path, set[str]] = {}
    failures: list[str] = []
    markdown_files = iter_markdown_files(root, exclude_dirs)

    for path in markdown_files:
        failures.extend(validate_markdown_file(root, path, anchor_cache))

    if failures:
        print("Markdown link check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"Checked {len(markdown_files)} Markdown files successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
