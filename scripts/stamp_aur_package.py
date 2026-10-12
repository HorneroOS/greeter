#!/usr/bin/env python3
"""Stamp the Hornero Greeter AUR package from its scoped release tag."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPOSITORY = "git+https://github.com/HorneroOS/greeter.git"
TAG_PREFIX = "pkg/hornero-greeter-v"


def stamp(pkgbuild: Path, tag: str) -> None:
    """Update pkgver and the source ref from a package-scoped tag."""
    if not tag.startswith(TAG_PREFIX):
        raise ValueError(f"invalid release tag: {tag}")
    version = tag.removeprefix(TAG_PREFIX)
    if not re.fullmatch(r"[0-9][A-Za-z0-9._+]*", version):
        raise ValueError(f"invalid Arch package version in release tag: {tag}")

    content = pkgbuild.read_text(encoding="utf-8")
    version_lines = re.findall(r"(?m)^pkgver=.*$", content)
    if len(version_lines) != 1:
        raise ValueError("expected exactly one pkgver assignment")

    source_matches = list(
        re.finditer(re.escape(REPOSITORY) + r"(?:#tag=[^\s\"']+)?", content)
    )
    if len(source_matches) != 1:
        raise ValueError("expected exactly one Hornero Greeter source URL")

    match = source_matches[0]
    content = (
        content[: match.start()]
        + f"{REPOSITORY}#tag={tag}"
        + content[match.end() :]
    )
    content = content.replace(version_lines[0], f"pkgver={version}", 1)
    pkgbuild.write_text(content, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: stamp_aur_package.py PKGBUILD pkg/hornero-greeter-vX.Y.Z",
            file=sys.stderr,
        )
        return 2
    try:
        stamp(Path(sys.argv[1]), sys.argv[2])
    except (OSError, ValueError) as error:
        print(f"STAMP-FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
