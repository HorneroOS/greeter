"""Tests for publishing the separately versioned greeter media archive."""

import hashlib
from pathlib import Path

import pytest

from scripts.stamp_media_aur_package import PACKAGE, stamp

PKGBUILD_TEMPLATE = """pkgname=hornero-greeter-media-base
pkgver=1.0.0
pkgrel=2
_media_tag=v0.1.0-preview
source=("hornero-greeter-media-base-${pkgver}.tar.zst::https://github.com/HorneroOS/greeter/releases/download/${_media_tag}/hornero-greeter-media-base-${pkgver}.tar.zst")
sha256sums=('old-checksum')
"""
WORKFLOW = Path(__file__).parents[1] / ".github/workflows/aur-publish-media.yml"
THEME_WORKFLOW = Path(__file__).parents[1] / ".github/workflows/aur-publish.yml"


def test_media_release_workflow_is_package_scoped() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    theme_workflow = THEME_WORKFLOW.read_text(encoding="utf-8")

    assert "types: [published]" in workflow
    assert "hornero-greeter-media-base-v" in workflow
    assert "pkgname: hornero-greeter-media-base" in workflow
    assert "pkgname: hornero-greeter-media-base" not in theme_workflow
    assert "ref: main" in workflow
    assert 'allow_empty_commits: "false"' in workflow
    assert 'allow_empty_commits: "false"' in theme_workflow


def test_stamp_sets_version_release_and_real_asset_checksum(tmp_path: Path) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    asset = tmp_path / f"{PACKAGE}-1.0.1.tar.zst"
    asset.write_bytes(b"release media archive fixture")
    pkgbuild.write_text(PKGBUILD_TEMPLATE, encoding="utf-8")

    stamp(pkgbuild, "hornero-greeter-media-base-v1.0.1", asset)

    result = pkgbuild.read_text(encoding="utf-8")
    assert "pkgver=1.0.1\n" in result
    assert "pkgrel=1\n" in result
    assert "_media_tag=hornero-greeter-media-base-v1.0.1\n" in result
    assert f"sha256sums=('{hashlib.sha256(asset.read_bytes()).hexdigest()}')" in result


def test_stamp_maps_preview_pkgver_and_keeps_release_tag(tmp_path: Path) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    asset = tmp_path / f"{PACKAGE}-1.1.0rc1.tar.zst"
    asset.write_bytes(b"preview media archive fixture")
    pkgbuild.write_text(PKGBUILD_TEMPLATE, encoding="utf-8")

    stamp(pkgbuild, "hornero-greeter-media-base-v1.1.0_preview1", asset)

    result = pkgbuild.read_text(encoding="utf-8")
    assert "pkgver=1.1.0rc1\n" in result
    assert "_media_tag=hornero-greeter-media-base-v1.1.0_preview1\n" in result


def test_preview_pkgver_sorts_before_stable_with_pacman_vercmp() -> None:
    import shutil
    import subprocess

    vercmp = shutil.which("vercmp")
    if vercmp is None:
        pytest.skip("pacman vercmp is unavailable")

    result = subprocess.run(
        [vercmp, "1.1.0rc1", "1.1.0"], check=True, capture_output=True, text=True
    )
    assert int(result.stdout.strip()) < 0


@pytest.mark.parametrize(
    ("tag", "asset_name"),
    [
        ("v1.0.1", f"{PACKAGE}-1.0.1.tar.zst"),
        ("hornero-greeter-media-base-v1.0.1", f"{PACKAGE}-1.0.2.tar.zst"),
        ("hornero-greeter-media-base-v1.0.1-preview", f"{PACKAGE}-1.0.1.tar.zst"),
    ],
)
def test_stamp_rejects_unscoped_tags_invalid_versions_and_mismatched_assets(
    tmp_path: Path, tag: str, asset_name: str
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    asset = tmp_path / asset_name
    asset.write_bytes(b"fixture")
    pkgbuild.write_text(PKGBUILD_TEMPLATE, encoding="utf-8")

    with pytest.raises(ValueError):
        stamp(pkgbuild, tag, asset)


def test_stamp_requires_asset_and_unambiguous_fields(tmp_path: Path) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    asset = tmp_path / f"{PACKAGE}-1.0.1.tar.zst"
    asset.write_bytes(b"fixture")
    incomplete = PKGBUILD_TEMPLATE.replace("_media_tag=v0.1.0-preview\n", "")
    pkgbuild.write_text(incomplete, encoding="utf-8")

    with pytest.raises(ValueError, match="_media_tag"):
        stamp(pkgbuild, "hornero-greeter-media-base-v1.0.1", asset)
    assert pkgbuild.read_text(encoding="utf-8") == incomplete


def test_stamp_does_not_write_when_release_asset_is_missing(tmp_path: Path) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    asset = tmp_path / f"{PACKAGE}-1.0.1.tar.zst"
    pkgbuild.write_text(PKGBUILD_TEMPLATE, encoding="utf-8")

    with pytest.raises(ValueError, match="does not exist"):
        stamp(pkgbuild, "hornero-greeter-media-base-v1.0.1", asset)

    assert pkgbuild.read_text(encoding="utf-8") == PKGBUILD_TEMPLATE
