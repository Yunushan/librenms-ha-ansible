#!/usr/bin/env python3
"""Parse repository YAML files with PyYAML.

This complements yamllint: yamllint enforces style, while this check is a small
syntax gate that also handles custom YAML tags such as Ansible Vault tags.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import yaml


DEFAULT_EXCLUDE_DIRS = {
    ".ansible",
    ".git",
}


class IgnoreUnknownTagsLoader(yaml.SafeLoader):
    """SafeLoader variant that tolerates Ansible-specific custom tags."""


def construct_unknown(loader: IgnoreUnknownTagsLoader, node: yaml.Node) -> Any:
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    return None


IgnoreUnknownTagsLoader.add_constructor(None, construct_unknown)


def should_skip(path: Path, exclude_dirs: set[str]) -> bool:
    return any(part in exclude_dirs for part in path.parts)


def iter_yaml_files(root: Path, exclude_dirs: set[str]) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file()
        and path.suffix in {".yml", ".yaml"}
        and not should_skip(path.relative_to(root), exclude_dirs)
    )


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
    failures: list[str] = []

    for path in iter_yaml_files(root, exclude_dirs):
        try:
            with path.open("r", encoding="utf-8") as handle:
                yaml.load(handle, Loader=IgnoreUnknownTagsLoader)
        except Exception as exc:  # noqa: BLE001 - CI should show exact parse error.
            failures.append(f"{path.relative_to(root)}: {exc}")

    if failures:
        print("YAML parsing failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"Parsed {len(iter_yaml_files(root, exclude_dirs))} YAML files successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
