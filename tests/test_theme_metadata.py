"""SDDM theme metadata contract: this is a Qt6 theme, so SDDM must run
sddm-greeter-qt6 (QtVersion=6). Without the key SDDM 0.21 starts the Qt5
greeter, which cannot load the theme and falls back to the embedded one."""
import configparser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKGBUILD = ROOT / "packaging/arch/hornero-greeter/PKGBUILD"


def test_metadata_declares_qt6():
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str
    cp.read(ROOT / "metadata.desktop")
    meta = cp["SddmGreeterTheme"]
    assert meta.get("QtVersion") == "6"
    assert meta.get("MainScript") == "Main.qml"


def test_theme_uses_qt6_only_modules():
    # Guard the reason for QtVersion=6: the port relies on Qt6-only APIs.
    qml = "\n".join(p.read_text() for p in ROOT.rglob("*.qml"))
    assert "import QtQuick.Effects" in qml


def test_arch_package_installs_qt6_theme_runtime():
    recipe = PKGBUILD.read_text()
    assert "'qt6-multimedia'" in recipe
    assert "'qt6-declarative'" in recipe
    assert "'qt5-multimedia'" not in recipe
    assert (
        "for f in theme.conf theme.conf.user metadata.desktop background.jpg; do\n"
        '    install -Dm644 "$src/$f" "${dest}$f"\n'
        "  done"
    ) in recipe
