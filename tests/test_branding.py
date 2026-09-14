"""HorneroOS branding layer: config, overlay, offline assets.

The branding layer is an optional overlay on the upstream greeter
contract: a small symbolic mark plus configurable tokens. layout,
interaction, and behavior stay upstream (see test_upstream_fidelity.py).
"""
import configparser
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
MARK = (REPO_ROOT / "components" / "BrandingMark.qml").read_text(encoding="utf-8")
LOGO = REPO_ROOT / "components" / "resources" / "hornero-symbolic.svg"

HEX_RE = re.compile(r'^"#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})"$')


def read_conf(name):
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / name, encoding="utf-8")
    return parser["General"]


def test_branding_keys_present_with_upstream_defaults():
    conf = read_conf("theme.conf")
    assert conf["brandingEnabled"] == "true"
    assert conf["brandingLogo"] == "components/resources/hornero-symbolic.svg"
    # Default accent stays the upstream red; a future Appearance System
    # may drive brandingAccent, but this milestone preserves the baseline.
    assert conf["brandingAccent"] == '"#e0342c"'


def test_branding_enabled_gate_and_single_instance():
    assert MAIN.count("BrandingMark {") == 1
    assert 'brandingEnabled: config.brandingEnabled != "false"' in MAIN
    # The mark degrades gracefully: a missing/unreadable logo file hides
    # the overlay instead of showing a broken-image icon.
    assert "status === Image.Ready" in MARK


def test_branding_logo_resolves_offline():
    conf = read_conf("theme.conf")
    logo = conf["brandingLogo"]
    assert "http://" not in logo and "https://" not in logo
    assert not logo.startswith(("/", "~"))
    assert (REPO_ROOT / logo).is_file()


def test_logo_asset_self_contained_and_credited():
    text = LOGO.read_text(encoding="utf-8")
    # The xmlns namespace declaration is not a network fetch.
    body = text.replace('xmlns="http://www.w3.org/2000/svg"', "")
    assert "<svg" in text and "viewBox" in text
    assert "http://" not in body and "https://" not in body
    assert "xlink:href" not in text
    # Provenance: official HorneroOS/config mark, flattened for QtSvg.
    assert "HorneroOS/config" in text


def test_accent_token_flows_to_topbar():
    assert MAIN.count("config.brandingAccent || config.actionBarFontColor") == 2
    # Error red stays hardcoded upstream; only the topbar accent is a token.
    assert 'tooltipFG: "#dc322f"' in MAIN


def test_mark_is_overlay_only():
    # Corner-anchored, fixed small size, no layout or behavior hooks.
    assert "anchors.right: parent.right" in MAIN
    assert "anchors.bottom: parent.bottom" in MAIN
    assert "width: 30" in MAIN and "height: 30" in MAIN
    assert "MouseArea" not in MARK
    assert "Gradient" not in MARK and "MultiEffect" not in MARK
    # No redesign language may return with the branding layer.
    for marker in ("GradientStop", "avatarBadge", "hairline", "locationLabel",
                   "uiScale", "loginRevealTimer", "loginCard"):
        assert marker not in MAIN, f"redesign marker returned: {marker}"
        assert marker not in MARK, f"redesign marker in mark: {marker}"


def test_no_network_in_branding_surface():
    for path in (REPO_ROOT / "components" / "BrandingMark.qml", LOGO):
        text = path.read_text(encoding="utf-8")
        body = text.replace('xmlns="http://www.w3.org/2000/svg"', "")
        assert "http://" not in body and "https://" not in body
    conf_text = (REPO_ROOT / "theme.conf").read_text(encoding="utf-8")
    assert "http://" not in conf_text and "https://" not in conf_text
