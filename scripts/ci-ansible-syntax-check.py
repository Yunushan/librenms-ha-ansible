#!/usr/bin/env python3
"""Run ansible-playbook --syntax-check across project playbooks."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


DEFAULT_HA_INVENTORY = "inventories/ha/hosts.yml"
DEFAULT_STANDALONE_INVENTORY = "inventories/standalone/hosts.yml"

STANDALONE_PLAYBOOKS = {
    "standalone.yml",
}


def playbook_inventory(playbook: Path, ha_inventory: str, standalone_inventory: str) -> str:
    if playbook.name in STANDALONE_PLAYBOOKS:
        return standalone_inventory
    return ha_inventory


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--playbooks-dir", default="playbooks", type=Path)
    parser.add_argument("--ha-inventory", default=DEFAULT_HA_INVENTORY)
    parser.add_argument("--standalone-inventory", default=DEFAULT_STANDALONE_INVENTORY)
    parser.add_argument(
        "--ansible-playbook",
        default=os.environ.get("ANSIBLE_PLAYBOOK", "ansible-playbook"),
        help="ansible-playbook executable to run",
    )
    parser.add_argument(
        "--extra-vars",
        action="append",
        default=[],
        help="extra var expression to pass to every syntax-check command",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    playbooks = sorted(args.playbooks_dir.glob("*.yml"))
    if not playbooks:
        print(f"No playbooks found under {args.playbooks_dir}", file=sys.stderr)
        return 1

    env = os.environ.copy()
    env.setdefault("ANSIBLE_HOST_KEY_CHECKING", "False")

    ansible_playbook = shutil.which(args.ansible_playbook)
    if ansible_playbook is None:
        print(
            "ansible-playbook was not found. Install ansible-core, run from WSL "
            "or a Linux controller, or use the project Docker image.",
            file=sys.stderr,
        )
        return 127

    failed: list[str] = []
    for playbook in playbooks:
        inventory = playbook_inventory(
            playbook,
            args.ha_inventory,
            args.standalone_inventory,
        )
        command = [
            ansible_playbook,
            "-i",
            inventory,
            str(playbook),
            "--syntax-check",
        ]
        for extra_var in args.extra_vars:
            command.extend(["-e", extra_var])

        print("+ " + " ".join(command))
        result = subprocess.run(command, env=env, check=False)
        if result.returncode != 0:
            failed.append(str(playbook))

    if failed:
        print("Ansible syntax-check failed:", file=sys.stderr)
        for playbook in failed:
            print(f"- {playbook}", file=sys.stderr)
        return 1

    print(f"Ansible syntax-check passed for {len(playbooks)} playbooks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
