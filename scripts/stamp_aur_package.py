#!/usr/bin/env python3
"""Stamp the Hornero Greeter AUR package from its scoped release tag."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPOSITORY = "git+https://github.com/HorneroOS/greeter.git"
TAG_PREFIX = "pkg/hornero-greeter-v"


def stamp(pkgbuild: Path, tag: str, release_sha: str) -> None:
    """Update pkgver and pin the source to the release commit."""
    if not tag.startswith(TAG_PREFIX):
        raise ValueError(f"invalid release tag: {tag}")
    if not re.fullmatch(r"[0-9a-fA-F]{40}", release_sha):
        raise ValueError("release commit must be a full 40-character SHA-1")
    upstream_version = tag.removeprefix(TAG_PREFIX)
    if not re.fullmatch(r"[0-9][A-Za-z0-9._+]*", upstream_version):
        raise ValueError(f"invalid Arch package version in release tag: {tag}")

    # Arch's version comparator sorts `_previewN` after the matching stable
    # version. Use the conventional `rcN` pkgver spelling while retaining the
    # original upstream tag in `source`.
    version = re.sub(r"_preview(?=\d)", "rc", upstream_version)

    content = pkgbuild.read_text(encoding="utf-8")
    version_lines = re.findall(r"(?m)^pkgver=.*$", content)
    if len(version_lines) != 1:
        raise ValueError("expected exactly one pkgver assignment")

    source_matches = list(
        re.finditer(
            re.escape(REPOSITORY) + r"(?:#(?:tag|commit)=[^\s\"')]+)?", content
        )
    )
    if len(source_matches) != 1:
        raise ValueError("expected exactly one Hornero Greeter source URL")

    match = source_matches[0]
    content = (
        content[: match.start()]
        + f"{REPOSITORY}#commit={release_sha.lower()}"
        + content[match.end() :]
    )
    content = content.replace(version_lines[0], f"pkgver={version}", 1)
    pkgbuild.write_text(content, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "usage: stamp_aur_package.py PKGBUILD pkg/hornero-greeter-vX.Y.Z RELEASE_SHA",
            file=sys.stderr,
        )
        return 2
    try:
        stamp(Path(sys.argv[1]), sys.argv[2], sys.argv[3])
    except (OSError, ValueError) as error:
        print(f"STAMP-FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
