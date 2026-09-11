"""Parse pinned ansible-core versions consistently across CI checks."""

from __future__ import annotations

import re
from typing import NamedTuple


_VERSION_PATTERN = re.compile(
    r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)"
    r"(?P<prerelease>[.]dev\d+|a\d+|b\d+|rc\d+)?$"
)


class AnsibleCoreVersion(NamedTuple):
    """The comparable parts of one exact ansible-core version pin."""

    major: int
    minor: int
    patch: int
    prerelease: str = ""

    @property
    def release(self) -> tuple[int, int]:
        return self.major, self.minor

    @property
    def stable(self) -> bool:
        return not self.prerelease


def parse_ansible_core_version(version: str | None) -> AnsibleCoreVersion | None:
    """Parse stable and prerelease exact pins used by the repository."""

    if version is None:
        return None
    match = _VERSION_PATTERN.fullmatch(version)
    if match is None:
        return None
    return AnsibleCoreVersion(
        int(match.group("major")),
        int(match.group("minor")),
        int(match.group("patch")),
        match.group("prerelease") or "",
    )


def controller_python_for_ansible_core(version: str | None) -> str | None:
    """Return the controller Python required by an ansible-core release line."""

    parsed = parse_ansible_core_version(version)
    if parsed is None:
        return None
    return "3.13" if parsed.release >= (2, 22) else "3.12"
