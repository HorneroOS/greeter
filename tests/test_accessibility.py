"""Accessibility: names, keyboard chain, large text, contrast, motion."""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
COMPONENTS = REPO_ROOT / "components"
FIELD = (COMPONENTS / "SignalField.qml").read_text(encoding="utf-8")
SELECT = (COMPONENTS / "SignalSelect.qml").read_text(encoding="utf-8")
BUTTON = (COMPONENTS / "SignalButton.qml").read_text(encoding="utf-8")
LIST = (COMPONENTS / "ChoiceList.qml").read_text(encoding="utf-8")

CHAIN = (
    "username_input_box", "password_input_box", "login_button", "session",
    "language", "keyboard_toggle", "reboot_button", "shutdown_button",
)


def test_login_and_system_controls_have_accessible_names():
    for name in (
        'accessibleName: "Username"',
        'accessibleName: "Password"',
        'accessibleName: "Desktop session"',
        'accessibleName: "Keyboard layout"',
        'Accessible.name: "Log in"',
        'accessibleName: "Restart computer"',
        'accessibleName: "Shut down computer"',
        'accessibleName: "Toggle on-screen keyboard"',
    ):
        assert name in MAIN, name
    assert "Accessible.passwordEdit: field.password" in FIELD
    # The wrapper's plaintext `text` alias is never exposed; only the
    # native (masking) TextInput is an accessible node.
    head, input_block = FIELD.split("TextInput {", 1)
    assert "Accessible.ignored: true" in head
    assert "Accessible.role: Accessible.EditableText" in input_block
    assert "Accessible.role: Accessible.ComboBox" in SELECT
    assert "Accessible.role: Accessible.Button" in BUTTON
    assert "Accessible.onPressAction: button.clicked()" in BUTTON


def test_every_control_is_focusable():
    for text in (FIELD, SELECT, BUTTON):
        assert "activeFocusOnTab: true" in text


def test_tab_chain_is_explicit_and_skips_hidden_controls():
    chain = re.search(r"var chain = \[(.*?)\];", MAIN)
    assert chain, "focusChain() list not found"
    assert [c.strip() for c in chain.group(1).split(",")] == list(CHAIN)
    assert "return item.visible && item.enabled;" in MAIN
    for control in CHAIN:
        assert f"container.moveFocus({control}, false)" in MAIN, control
        assert f"container.moveFocus({control}, true)" in MAIN, control


def test_enter_logs_in_and_buttons_take_keyboard_activation():
    assert MAIN.count("onAccepted: container.login()") == 2
    assert "onClicked: container.login()" in MAIN
    assert "sddm.login(username_input_box.text, password_input_box.text, container.sessionSource(session.index))" in MAIN
    for key in ("Qt.Key_Return", "Qt.Key_Enter", "Qt.Key_Space"):
        assert key in BUTTON
        assert key in SELECT


def test_lists_are_keyboard_operable_and_return_focus():
    assert "Qt.Key_Escape" in LIST
    assert "list.trigger.forceActiveFocus()" in LIST
    # A closed list drops its sub-focus and stops taking keys.
    assert "view.focus = false;" in LIST and "enabled: list.open" in LIST
    hide = LIST.split("function choose(i)", 1)[1].split("}", 1)[0]
    assert hide.index("list.hide(true)") < hide.index("list.chosen(i)")
    assert "Qt.Key_Up" in SELECT and "Qt.Key_Down" in SELECT
    # User chooser: Down in the username field opens the user list.
    assert "event.key === Qt.Key_Down && userModel.count > 1" in MAIN


def test_failed_login_keeps_username_and_refocuses_password():
    handler = MAIN.split("function onLoginFailed()", 1)[1].split("}", 1)[0]
    assert "password_input_box.forceActiveFocus()" in handler
    assert "username_input_box.text" not in handler
    assert "textConstants.loginFailed" in handler


def test_first_keypress_is_not_swallowed():
    assert "target.text += event.text;" in MAIN


def test_virtual_keyboard_can_be_toggled_and_is_off_by_default():
    assert "property bool virtualKeyboardVisible: container.virtualKeyboardAvailable && Qt.inputMethod.visible" in MAIN
    assert "Qt.inputMethod.show()" in MAIN
    assert "Qt.inputMethod.hide()" in MAIN
    assert 'config.virtualKeyboardEnabled == "true"' in MAIN
    assert "virtualKeyboard.height" in MAIN
    assert "onClicked: container.toggleVirtualKeyboard()" in MAIN


def test_large_text_scales_type_one_and_a_half_times():
    assert "property real accessibilityScale: largeText ? 1.5 : 1.0" in MAIN
    assert "container.typeUnit * container.accessibilityScale" in MAIN
    assert "typeUnit: Math.max(1.0, unit)" in MAIN


def test_high_contrast_switches_palette():
    assert "readonly property var sig: Signal.palette(highContrast)" in MAIN


def test_focus_is_visible_ring_plus_registration_tick():
    for text in (FIELD, SELECT, BUTTON):
        assert "border.width: 2" in text and ".sig.focus" in text
        assert "width: 10\n        height: 2" in text


def test_reduced_motion_is_honoured():
    assert 'property bool reducedMotion: config.reducedMotion == "true"' in MAIN
    for text in (MAIN, FIELD, SELECT, BUTTON, LIST):
        for call in re.findall(r"Signal\.(?:duration|fadeDuration)\([^)]*\)", text):
            assert "reducedMotion" in call, call


def test_login_failure_line_is_readable_and_has_icon_and_word():
    # greeter#45: the failure line was ~9 px. It must keep a >= 13 px floor,
    # an alert glyph and the localised word, never colour alone.
    assert "font.pixelSize: Math.max(13, Signal.TYPE.normal * login_container.s)" in MAIN
    assert 'name: "alert-triangle"' in MAIN
    assert "textConstants.loginFailed" in MAIN
    assert "Accessible.AlertMessage" in MAIN


def test_experimental_sessions_are_listed_last_and_never_default():
    # greeter#45: stable sessions first, experimental last with a word chip;
    # the default is never an experimental session.
    assert "id: sessionChoices" in MAIN
    assert "(a.experimental ? 2 : 0)" in MAIN
    assert "!rows[last].experimental" in MAIN
    assert "model: sessionChoices" in MAIN
    assert "index: container.sessionDefault" in MAIN
    chips = (REPO_ROOT / "components" / "ChoiceList.qml").read_text(encoding="utf-8")
    assert '"EXPERIMENTAL"' in chips
