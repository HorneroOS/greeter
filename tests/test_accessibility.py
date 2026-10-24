"""Accessibility affordances stay discoverable and configurable."""
from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
TOGGLE = (REPO_ROOT / "components" / "KeyboardToggle.qml").read_text(encoding="utf-8")


def test_login_and_system_controls_have_accessible_names():
    for name in (
        'Accessible.name: "Username"',
        'Accessible.name: "Password"',
        'Accessible.name: "Desktop session"',
        'Accessible.name: "Keyboard layout"',
        'Accessible.name: "Log in"',
        'Accessible.name: "Restart computer"',
        'Accessible.name: "Shut down computer"',
    ):
        assert name in MAIN
    assert 'Accessible.name: "Toggle on-screen keyboard"' in TOGGLE
    for control in (
        "clear_passwd_button",
        "login_button",
        "session",
        "language",
        "reboot_button",
        "shutdown_button",
    ):
        assert re.search(rf"\bid: {control}\s+activeFocusOnTab: true\b", MAIN)


def test_virtual_keyboard_can_be_toggled_and_is_off_by_default():
    assert 'property bool virtualKeyboardVisible: container.virtualKeyboardAvailable && Qt.inputMethod.visible' in MAIN
    assert "Qt.inputMethod.show()" in MAIN
    assert "Qt.inputMethod.hide()" in MAIN
    assert 'config.virtualKeyboardEnabled == "true"' in MAIN
    assert "virtualKeyboard.height" in MAIN
    assert 'fader.state = "on"' in MAIN
    assert 'if (fader.state == "off") {\n                fader.state = "on";' in MAIN
    assert "login_button.forceActiveFocus()" in MAIN
    assert "clear_passwd_button.forceActiveFocus()" in MAIN
    assert "KeyNavigation.tab: language" in MAIN

    assert "activeFocusOnTab: true" in TOGGLE
    assert "onClicked: control.toggleRequested()" in TOGGLE
    assert "Accessible.onPressAction: control.toggleRequested()" in TOGGLE


def test_large_text_scales_fonts_at_least_one_and_a_half_times():
    assert 'property real accessibilityScale: largeText ? 1.5 : 1.0' in MAIN
    assert "font.pointSize: config.clockFontSize * container.accessibilityScale" in MAIN
    assert "font.pixelSize: config.labelFontSize * container.accessibilityScale" in MAIN


def test_high_contrast_adds_control_backplates_and_bright_text():
    assert 'property color accessibleForeground: highContrast ? "#ffffff" : config.labelFontColor' in MAIN
    assert 'visible: container.highContrast' in MAIN
    assert 'color: container.highContrast ? "#e6000000" : "transparent"' in MAIN
