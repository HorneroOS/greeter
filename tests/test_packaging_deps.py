"""Arch package dependency contract: the greeter is Qt6, never Qt5.

Parses packaging PKGBUILDs and cross-checks them against the QML imports
the theme actually uses, so a Qt5 dependency cannot regress unnoticed.
Also guards against committing VCS checkout byproducts (a stray
makepkg/AUR git clone was once tracked under packaging/).
"""
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
GREETER_PKGBUILD = (
    REPO_ROOT / "packaging" / "arch" / "hornero-greeter" / "PKGBUILD"
)

# QML module -> Arch runtime package providing it.
QML_RUNTIME_MAP = {
    "QtMultimedia": "qt6-multimedia",
    "QtQuick.Effects": "qt6-declarative",
    "QtQuick.Shapes": "qt6-declarative",
    "QtQuick": "qt6-declarative",
    "QtQuick.VirtualKeyboard": "qt6-virtualkeyboard",
}

FORBIDDEN_DEPENDENCY_RES = (
    re.compile(r"^qt5", re.IGNORECASE),
    re.compile(r"^qt-5", re.IGNORECASE),
)


def _array_values(pkgbuild: Path, name: str) -> list[str]:
    text = pkgbuild.read_text(encoding="utf-8")
    match = re.search(rf"^{name}=\((.*?)\)", text, re.MULTILINE | re.DOTALL)
    assert match, f"{pkgbuild}: {name} array not found"
    return re.findall(r"'([^']+)'|\"([^\"]+)\"", match.group(1))


def _depends() -> list[str]:
    values = _array_values(GREETER_PKGBUILD, "depends")
    return [a or b for a, b in values]


def _optdepends() -> list[str]:
    values = _array_values(GREETER_PKGBUILD, "optdepends")
    return [(a or b).split(":", 1)[0] for a, b in values]


# Files loaded on demand through a Loader: their imports are optional
# runtime dependencies (the theme keeps working when the module is absent).
OPTIONAL_QML = {"UserVideo.qml"}


def _qml_imports(optional: bool = False) -> set[str]:
    imports: set[str] = set()
    for path in (
        [REPO_ROOT / "Main.qml", *sorted((REPO_ROOT / "components").glob("*.qml"))]
    ):
        if (path.name in OPTIONAL_QML) != optional:
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            match = re.match(r"\s*import\s+(\S+)", line)
            if match:
                imports.add(match.group(1))
    return imports


def test_pkgbuild_has_no_qt5_dependency():
    depends = _depends()
    assert depends, "depends array is empty"
    for dep in depends:
        base = re.split(r"[<>=]", dep, maxsplit=1)[0].strip()
        for forbidden in FORBIDDEN_DEPENDENCY_RES:
            assert not forbidden.match(base), f"Qt5 regression: depends has {dep!r}"


def test_multimedia_is_optional():
    # The default greeter plays no media. QtMultimedia is only imported by
    # the opt-in UserVideo.qml (Loader), so it is an optional dependency,
    # and the retired media pack is no longer referenced at all.
    assert "QtMultimedia" not in _qml_imports()
    assert "QtMultimedia" in _qml_imports(optional=True)
    assert "qt6-multimedia" not in _depends()
    assert "gst-plugins-good" not in _depends()
    assert "qt6-multimedia" in _optdepends()
    text = GREETER_PKGBUILD.read_text(encoding="utf-8")
    assert "hornero-greeter-media-base" not in text
    assert "media/base" not in text
    main = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
    assert 'source: active ? "components/UserVideo.qml" : ""' in main


def test_pkgbuild_declares_signal_fonts():
    # Hornero Signal type (RFC 0001 §3.3): IBM Plex Sans / Mono / Sans
    # Condensed from ttf-ibm-plex. Rubik is gone with the old identity.
    signal = (REPO_ROOT / "components" / "Signal.js").read_text(encoding="utf-8")
    for family in ("IBM Plex Sans", "IBM Plex Mono", "IBM Plex Sans Condensed"):
        assert f'"{family}"' in signal
    assert "ttf-ibm-plex" in _depends()
    assert "ttf-rubik-vf" not in _depends()


def test_pkgbuild_version_matches_its_source_tag():
    text = GREETER_PKGBUILD.read_text(encoding="utf-8")
    version = re.search(r"^pkgver=([0-9][A-Za-z0-9._+~-]*)$", text, re.MULTILINE)
    source_tag = re.search(r"#tag=v([0-9][A-Za-z0-9._+~-]*)", text)
    assert version and source_tag, "PKGBUILD must pin a versioned greeter tag"
    assert version.group(1) == source_tag.group(1), "pkgver and source tag drifted"
    assert "github.com/HorneroOS/greeter.git" in text


def test_qml_imports_covered_by_depends():
    imports = _qml_imports()
    depends = _depends()
    for module, package in QML_RUNTIME_MAP.items():
        if module in imports:
            assert package in depends, (
                f"QML imports {module} but depends lacks {package}"
            )


def test_no_committed_vcs_checkout_byproducts():
    # A nested VCS checkout looks like a directory containing HEAD plus
    # objects/ and refs/ (makepkg git-source byproduct). .gitignore already
    # names /hornero-greeter/; this test fails if one is ever committed.
    offenders = [
        path
        for path in (REPO_ROOT / "packaging").rglob("*")
        if path.is_dir()
        and (path / "HEAD").is_file()
        and (path / "objects").is_dir()
        and (path / "refs").is_dir()
    ]
    assert offenders == [], f"checkout byproducts present: {offenders[:5]}"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-q"]))
