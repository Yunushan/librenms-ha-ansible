#!/usr/bin/env python3
"""Check project-local Ansible collections against exact requirements pins."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml


MISMATCH_EXIT = 10
COLLECTION_NAME_PATTERN = re.compile(r"^[A-Za-z0-9_]+\.[A-Za-z0-9_]+$")
EXACT_VERSION_PATTERN = re.compile(r"^(?:==)?([A-Za-z0-9][A-Za-z0-9._+-]*)$")


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def load_requirements(path: Path) -> list[tuple[str, str]]:
    with path.open("r", encoding="utf-8") as handle:
        data: Any = yaml.safe_load(handle) or {}

    if not isinstance(data, dict) or not isinstance(data.get("collections"), list):
        raise ValueError(f"{path} must contain a collections list")

    pins: list[tuple[str, str]] = []
    for entry in data["collections"]:
        if not isinstance(entry, dict):
            raise ValueError(
                "every collection requirement must use name and version keys",
            )

        name = str(entry.get("name", "")).strip()
        version_value = str(entry.get("version", "")).strip()
        if not COLLECTION_NAME_PATTERN.fullmatch(name):
            raise ValueError(f"invalid collection name: {name or '<empty>'}")

        version_match = EXACT_VERSION_PATTERN.fullmatch(version_value)
        if version_match is None:
            raise ValueError(f"collection {name} must use one exact version pin")

        pins.append((name, version_match.group(1)))

    if not pins:
        raise ValueError(f"{path} does not define any collection pins")
    return pins


def installed_version(collections_path: Path, name: str) -> tuple[str | None, bool]:
    namespace, collection = name.split(".", maxsplit=1)
    collection_dir = collections_path / "ansible_collections" / namespace / collection
    if not collection_dir.exists():
        return None, False

    manifest_path = collection_dir / "MANIFEST.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        version = manifest["collection_info"]["version"]
    except (KeyError, OSError, TypeError, json.JSONDecodeError):
        return "<invalid metadata>", True

    return str(version), True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--requirements", required=True, type=Path)
    parser.add_argument("--collections-path", required=True, type=Path)
    parser.add_argument("--require-installed", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        pins = load_requirements(args.requirements)
    except (OSError, ValueError, yaml.YAMLError) as error:
        return fail(str(error))

    mismatches: list[str] = []
    for name, required_version in pins:
        current_version, is_installed = installed_version(args.collections_path, name)
        if not is_installed and not args.require_installed:
            continue
        if current_version != required_version:
            rendered_version = current_version if is_installed else "<not installed>"
            mismatches.append(
                f"{name}: installed {rendered_version}, required {required_version}",
            )

    if mismatches:
        print("Pinned Ansible collection version mismatch detected:")
        for mismatch in mismatches:
            print(f"- {mismatch}")
        return MISMATCH_EXIT

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
