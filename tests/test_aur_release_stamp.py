"""Regression tests for the package-scoped Greeter AUR release tag."""

from pathlib import Path

import pytest

from scripts.stamp_aur_package import REPOSITORY, stamp

WORKFLOW = Path(__file__).parents[1] / ".github/workflows/aur-publish.yml"
RELEASE_SHA = "a" * 40


def test_aur_workflow_only_listens_to_the_greeter_package_namespace() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    assert '"pkg/hornero-greeter-v*"' in workflow
    assert '"v*"' not in workflow
    assert "RELEASE_SHA: ${{ github.sha }}" in workflow
    assert '"${RELEASE_SHA}"' in workflow
    assert workflow.index("Verify release commit is on main") < workflow.index(
        "Stamp pkgver and source commit"
    ) < workflow.index("Publish AUR package")


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
            "1.1.0rc1",
        ),
    ],
)
def test_stamp_updates_version_and_source_tag(
    tmp_path: Path, source: str, tag: str, expected_version: str
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(f"pkgver=1.0.3\n{source}\n", encoding="utf-8")

    stamp(pkgbuild, tag, RELEASE_SHA)

    result = pkgbuild.read_text(encoding="utf-8")
    assert f"pkgver={expected_version}" in result
    assert f"{REPOSITORY}#commit={RELEASE_SHA}" in result
    assert result.count(REPOSITORY) == 1


def test_stamp_preserves_unquoted_vcs_source_closing_parenthesis(
    tmp_path: Path,
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(
        f"pkgver=1.0.3\nsource=({REPOSITORY})\n", encoding="utf-8"
    )

    stamp(pkgbuild, "pkg/hornero-greeter-v1.0.4", RELEASE_SHA)

    result = pkgbuild.read_text(encoding="utf-8")
    assert f"source=({REPOSITORY}#commit={RELEASE_SHA})" in result


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
        stamp(pkgbuild, tag, RELEASE_SHA)


@pytest.mark.parametrize("release_sha", ["", "a" * 39, "a" * 41, "g" * 40])
def test_stamp_rejects_invalid_release_sha(
    tmp_path: Path, release_sha: str
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(
        f"pkgver=1.0.3\nsource=(\"pkg::{REPOSITORY}\")\n", encoding="utf-8"
    )

    with pytest.raises(ValueError):
        stamp(pkgbuild, "pkg/hornero-greeter-v1.0.4", release_sha)
