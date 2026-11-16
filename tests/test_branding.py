"""HorneroOS branding on the greeter: mark, diagonal, offline assets."""
import configparser
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
MARK = (REPO_ROOT / "components" / "BrandingMark.qml").read_text(encoding="utf-8")
LOGO = REPO_ROOT / "components" / "resources" / "hornero-symbolic.svg"


def read_conf(name):
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / name, encoding="utf-8")
    return parser["General"]


def test_branding_keys_present():
    conf = read_conf("theme.conf")
    assert conf["brandingEnabled"] == "true"
    assert conf["brandingLogo"] == "components/resources/hornero-symbolic.svg"


def test_branding_enabled_gate_and_single_instance():
    assert MAIN.count("BrandingMark {") == 1
    assert 'brandingEnabled: config.brandingEnabled != "false"' in MAIN
    # A missing/unreadable logo hides the mark instead of a broken image.
    assert "status === Image.Ready" in MARK


def test_branding_logo_resolves_offline():
    logo = read_conf("theme.conf")["brandingLogo"]
    assert "http://" not in logo and "https://" not in logo
    assert not logo.startswith(("/", "~"))
    assert (REPO_ROOT / logo).is_file()


def test_logo_asset_self_contained_and_credited():
    text = LOGO.read_text(encoding="utf-8")
    body = text.replace('xmlns="http://www.w3.org/2000/svg"', "")
    assert "<svg" in text and "viewBox" in text
    assert "http://" not in body and "https://" not in body
    assert "xlink:href" not in text
    assert "HorneroOS/config" in text


def test_mark_has_no_interaction():
    assert "MouseArea" not in MARK


def test_la_plata_diagonal_only_on_brand_surfaces():
    # RFC 0001 §2: the 45° diagonal appears on brand surfaces, never inside
    # controls. The greeter uses it in the console header and bottom rail.
    assert MAIN.count("DiagonalHatch {") == 2
    for control in ("SignalField", "SignalSelect", "SignalButton", "ChoiceList"):
        text = (REPO_ROOT / "components" / f"{control}.qml").read_text(encoding="utf-8")
        assert "DiagonalHatch" not in text, control
    hatch = (REPO_ROOT / "components" / "DiagonalHatch.qml").read_text(encoding="utf-8")
    assert "rotation: 45" in hatch


def test_no_network_in_branding_surface():
    for path in (REPO_ROOT / "components" / "BrandingMark.qml", LOGO):
        body = path.read_text(encoding="utf-8").replace('xmlns="http://www.w3.org/2000/svg"', "")
        assert "http://" not in body and "https://" not in body
