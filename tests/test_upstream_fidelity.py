"""Upstream visual fidelity: the greeter looks like aerial-sddm-theme.

The Qt6 port restores the upstream layout verbatim (centered clock
column, label-left login rows, top action bar, upstream palette and
metrics). The only intentional visual change is local Argentina clips
instead of the streamed Apple TV playlists (offline invariant).
"""
import configparser
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")

UPSTREAM_VALUES = {
    "displayFont": '"Droid Sans Mono for Powerline"',
    "clockFontSize": '"72"',
    "dateFontSize": '"24"',
    "labelFontSize": '"16"',
    "errorMsgFontSize": '"12"',
    "actionBarFontSize": '"14"',
    "timeFormat": '"hh:mm"',
    "dateFormat": '"dddd, dd MMMM yyyy"',
    "passwordLeftMargin": "15",
    "usernameLeftMargin": "15",
    "relativePositionX": "0.3",
    "relativePositionY": "0.7",
    "errorMsgFontColor": '"#dc322f"',
    "clockFontColor": '"white"',
    "labelFontColor": '"white"',
    "actionBarFontColor": '"#e0342c"',
}

REMOVED_IDENTITY_KEYS = (
    "creamColor", "mutedColor", "accentColor", "terracottaColor",
    "surfaceColor", "surfaceBorderColor", "locationLabel",
    "locationFontSize", "showAvatar", "avatarImage",
)

UPSTREAM_IDS = (
    "id: clock", "id: time", "id: date", "id: login_container",
    "id: username_row", "id: username_label", "id: username_input_box",
    "id: password_row", "id: password_label", "id: password_input_box",
    "id: clear_passwd_button", "id: login_button", "id: error_message",
    "id: actionBar", "id: row_left", "id: row_right", "id: session",
    "id: language", "id: reboot_button", "id: shutdown_button",
)

REDESIGN_MARKERS = (
    "GradientStop", "avatarBadge", "avatarFallback", "hairline",
    "locationLabel", "uiScale", "loginRevealTimer", "loginCard",
    "identityRow", "container.cream", "container.terra",
    "container.accent", "container.muted",
)


def read_conf(name):
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / name, encoding="utf-8")
    return parser["General"]


def test_upstream_theme_values():
    conf = read_conf("theme.conf")
    for key, value in UPSTREAM_VALUES.items():
        assert conf[key] == value, f"{key} diverged: {conf[key]}"


def test_no_identity_keys():
    conf = read_conf("theme.conf")
    for key in REMOVED_IDENTITY_KEYS:
        assert key not in conf, f"redesign key still present: {key}"


def test_upstream_structure_present():
    for obj in UPSTREAM_IDS:
        assert obj in MAIN, f"missing upstream element {obj}"


def test_no_redesign_markers():
    for marker in REDESIGN_MARKERS:
        assert marker not in MAIN, f"redesign marker still present: {marker}"


def test_login_button_upstream_style():
    assert 'text: ">"' in MAIN
    assert 'color: "#393939"' in MAIN
    assert 'activeColor: "#268bd2"' in MAIN


def test_video_preserve_aspect_crop():
    deck = (REPO_ROOT / "components" / "MediaDeck.qml").read_text(encoding="utf-8")
    assert deck.count("VideoOutput.PreserveAspectCrop") == 2
    assert MAIN.count("PreserveAspectCrop") >= 2


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
