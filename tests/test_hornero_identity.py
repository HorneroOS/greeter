"""Hornero identity contract: palette, hero, login card, responsive layout."""
import configparser
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")


def read_conf(name):
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / name, encoding="utf-8")
    return parser["General"]


HEX_RE = re.compile(r"^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")

PALETTE_KEYS = (
    "creamColor", "mutedColor", "accentColor", "terracottaColor",
    "surfaceColor", "surfaceBorderColor",
)


def test_palette_keys_present_and_hex():
    conf = read_conf("theme.conf")
    for key in PALETTE_KEYS:
        assert key in conf, f"missing palette key: {key}"
        assert HEX_RE.match(conf[key]), f"{key} is not a hex color: {conf[key]}"


def test_palette_is_hornero_not_upstream():
    conf = read_conf("theme.conf")
    palette = {conf[k].lower() for k in PALETTE_KEYS}
    # Upstream accent red must be gone from the identity palette.
    assert "#e0342c" not in palette
    assert conf["actionBarFontColor"].lower() != "#e0342c"


def test_location_label_present_and_plain():
    conf = read_conf("theme.conf")
    assert "locationLabel" in conf and conf["locationLabel"].strip()
    assert "http://" not in conf["locationLabel"]
    assert "https://" not in conf["locationLabel"]
    assert "locationFontSize" in conf


def test_avatar_keys_present():
    conf = read_conf("theme.conf")
    assert conf["showAvatar"] in ("true", "false")
    assert "avatarImage" in conf
    assert not conf["avatarImage"].startswith(("http://", "https://", "/"))


def test_hero_grade_overlays_present():
    assert "GradientStop" in MAIN
    assert "orientation: Gradient.Horizontal" in MAIN or "Gradient.Horizontal" in MAIN


def test_video_hero_preserve_aspect_crop():
    deck = (REPO_ROOT / "components" / "MediaDeck.qml").read_text(encoding="utf-8")
    assert MAIN.count("PreserveAspectCrop") >= 3
    assert deck.count("VideoOutput.PreserveAspectCrop") == 2


def test_clock_date_location_login_present():
    for obj in ("id: time", "id: date", "id: locationLabel", "id: loginCard"):
        assert obj in MAIN, f"missing hero element {obj}"


def test_avatar_with_graceful_fallback():
    assert "id: avatarBadge" in MAIN
    assert "id: avatarFallback" in MAIN
    assert "Image.Ready" in MAIN


def test_password_masked_and_keyboard_flow():
    assert "PasswordBox" in MAIN
    for nav in (
        "KeyNavigation.tab: password_input_box",
        "KeyNavigation.tab: login_button",
        "KeyNavigation.tab: reboot_button",
        "KeyNavigation.tab: shutdown_button",
        "KeyNavigation.tab: session",
        "KeyNavigation.tab: username_input_box",
    ):
        assert nav in MAIN, f"missing keyboard link {nav}"
    assert MAIN.count("sddm.login(username_input_box.text") >= 3


def test_responsive_scale_expression():
    assert "uiScale" in MAIN
    assert "/ 1280" in MAIN and "/ 720" in MAIN


def test_sddm_contract_preserved():
    for token in (
        "userModel.lastUser", "sessionModel", "keyboard.layouts",
        "keyboard.currentLayout", "sddm.canReboot", "sddm.canPowerOff",
        "onLoginFailed", "textConstants.loginFailed", "MediaDeck",
        "showLoginButton", "showTopBar", "autofocusInput",
    ):
        assert token in MAIN, f"SDDM contract token missing: {token}"


def test_no_urls_on_screen():
    body = MAIN.split("import ", 1)[-1]
    assert "http://" not in body and "https://" not in body
