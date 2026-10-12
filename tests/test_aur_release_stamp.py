"""Regression tests for the package-scoped Greeter AUR release tag."""

from pathlib import Path

import pytest

from scripts.stamp_aur_package import REPOSITORY, stamp

WORKFLOW = Path(__file__).parents[1] / ".github/workflows/aur-publish.yml"


def test_aur_workflow_only_listens_to_the_greeter_package_namespace() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    assert '"pkg/hornero-greeter-v*"' in workflow
    assert '"v*"' not in workflow


@pytest.mark.parametrize(
    ("source", "tag", "expected_version"),
    [
        (
            f'source=("pkg::{REPOSITORY}#tag=v1.0.3")',
            "pkg/hornero-greeter-v1.0.4",
            "1.0.4",
        ),
        (
            f'source=("pkg::{REPOSITORY}")',
            "pkg/hornero-greeter-v1.1.0_preview1",
            "1.1.0_preview1",
        ),
    ],
)
def test_stamp_updates_version_and_source_tag(
    tmp_path: Path, source: str, tag: str, expected_version: str
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(f"pkgver=1.0.3\n{source}\n", encoding="utf-8")

    stamp(pkgbuild, tag)

    result = pkgbuild.read_text(encoding="utf-8")
    assert f"pkgver={expected_version}" in result
    assert f"{REPOSITORY}#tag={tag}" in result
    assert result.count(REPOSITORY) == 1


@pytest.mark.parametrize(
    ("content", "tag"),
    [
        ("pkgver=1.0.3\n", "pkg/hornero-greeter-v1.0.4"),
        (f"pkgver=1.0.3\n{REPOSITORY}\n", "v1.0.4"),
        (f"pkgver=1.0.3\n{REPOSITORY}\n", "pkg/hornero-greeter-v1.0.4-preview1"),
        (f"pkgver=1.0.3\n{REPOSITORY}\n", "pkg/hornero-config-v1.0.4"),
    ],
)
def test_stamp_rejects_ambiguous_or_unscoped_input(
    tmp_path: Path, content: str, tag: str
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(content, encoding="utf-8")

    with pytest.raises(ValueError):
        stamp(pkgbuild, tag)
