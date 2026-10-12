#!/usr/bin/env python3
"""Stamp the media-base AUR package from its published release asset."""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

PACKAGE = "hornero-greeter-media-base"
TAG_PREFIX = f"{PACKAGE}-v"


def _replace_once(content: str, pattern: str, replacement: str, label: str) -> str:
    """Replace one unambiguous PKGBUILD field or fail without writing."""
    if len(re.findall(pattern, content, re.MULTILINE)) != 1:
        raise ValueError(f"expected exactly one {label} assignment")
    updated, count = re.subn(pattern, replacement, content, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"could not update {label}")
    return updated


def stamp(pkgbuild: Path, tag: str, asset: Path) -> None:
    """Update package version, source release tag, and checksum from an asset."""
    if not tag.startswith(TAG_PREFIX):
        raise ValueError(f"invalid media release tag: {tag}")
    upstream_version = tag.removeprefix(TAG_PREFIX)
    if not re.fullmatch(r"[0-9][A-Za-z0-9._+]*", upstream_version):
        raise ValueError(f"invalid Arch package version in release tag: {tag}")
    version = re.sub(r"_preview(?=\d)", "rc", upstream_version)
    expected_name = f"{PACKAGE}-{version}.tar.zst"
    if asset.name != expected_name:
        raise ValueError(f"expected release asset named {expected_name}")
    if not asset.is_file():
        raise ValueError(f"release asset does not exist: {asset}")
    if asset.stat().st_size == 0:
        raise ValueError("release asset must not be empty")

    with asset.open("rb") as asset_file:
        checksum = hashlib.file_digest(asset_file, "sha256").hexdigest()
    content = pkgbuild.read_text(encoding="utf-8")
    package_lines = re.findall(r"^pkgname=.*$", content, re.MULTILINE)
    source_lines = re.findall(r"^source=.*$", content, re.MULTILINE)
    expected_source_suffix = (
        f"releases/download/${{_media_tag}}/{PACKAGE}-${{pkgver}}.tar.zst"
    )
    if package_lines != [f"pkgname={PACKAGE}"]:
        raise ValueError(f"PKGBUILD must define pkgname={PACKAGE} exactly once")
    if len(source_lines) != 1 or expected_source_suffix not in source_lines[0]:
        raise ValueError("PKGBUILD source must use the versioned media release URL")
    content = _replace_once(content, r"^pkgver=.*$", f"pkgver={version}", "pkgver")
    content = _replace_once(content, r"^pkgrel=.*$", "pkgrel=1", "pkgrel")
    content = _replace_once(
        content, r"^_media_tag=.*$", f"_media_tag={tag}", "_media_tag"
    )
    content = _replace_once(
        content,
        r"^sha256sums=\(.*\)$",
        f"sha256sums=('{checksum}')",
        "sha256sums",
    )
    pkgbuild.write_text(content, encoding="utf-8")


def main() -> int:
    """Stamp the media package using a release tag and downloaded archive."""
    if len(sys.argv) != 4:
        print(
            "usage: stamp_media_aur_package.py PKGBUILD "
            "hornero-greeter-media-base-vX.Y.Z ASSET",
            file=sys.stderr,
        )
        return 2
    try:
        stamp(Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]))
    except (OSError, ValueError) as error:
        print(f"STAMP-FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
