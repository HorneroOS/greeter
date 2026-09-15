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
    "QtQuick": "qt6-declarative",
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


def _qml_imports() -> set[str]:
    imports: set[str] = set()
    for path in (
        [REPO_ROOT / "Main.qml", *sorted((REPO_ROOT / "components").glob("*.qml"))]
    ):
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


def test_pkgbuild_declares_qt6_multimedia():
    assert "qt6-multimedia" in _depends()


def test_qml_imports_covered_by_depends():
    imports = _qml_imports()
    assert "QtMultimedia" in imports, "expected the MediaDeck to import QtMultimedia"
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
