"""Accessibility: names, keyboard chain, large text, contrast, motion."""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
GREETD_MAIN = (REPO_ROOT / "greetd" / "qml" / "Main.qml").read_text(encoding="utf-8")
COMPONENTS = REPO_ROOT / "components"
FIELD = (COMPONENTS / "SignalField.qml").read_text(encoding="utf-8")
SELECT = (COMPONENTS / "SignalSelect.qml").read_text(encoding="utf-8")
BUTTON = (COMPONENTS / "SignalButton.qml").read_text(encoding="utf-8")
LIST = (COMPONENTS / "ChoiceList.qml").read_text(encoding="utf-8")
STRIP = (COMPONENTS / "ChannelStrip.qml").read_text(encoding="utf-8")

CHAIN = (
    "channels", "username_input_box", "password_input_box", "login_button",
    "session", "language", "keyboard_toggle", "suspend_button",
    "reboot_button", "shutdown_button",
)


def test_login_and_system_controls_have_accessible_names():
    # Names come from the localised a11y.* keys (tests/test_strings.py
    # checks both languages define them).
    for name in (
        'accessibleName: container.tr("a11y.username")',
        'accessibleName: container.tr("a11y.password")',
        'accessibleName: container.tr("a11y.session")',
        'accessibleName: container.tr("a11y.layout")',
        'accessibleName: container.tr("a11y.login")',
        'accessibleName: container.tr("a11y.suspend")',
        'accessibleName: container.tr("a11y.restart")',
        'accessibleName: container.tr("a11y.shutdown")',
        'accessibleName: container.tr("a11y.keyboard")',
        'accessibleName: container.tr("a11y.cancel")',
        'Accessible.name: container.tr("a11y.confirm")',
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
    # The channel strip is one list; its description always names the
    # tuned account ("Account 2 of 3: Ana") and how to change it.
    assert "Accessible.role: Accessible.List" in STRIP
    assert 'Strings.t(lang, "a11y.channel")' in STRIP
    assert "Accessible.Dialog" in MAIN


def test_every_control_is_focusable():
    for text in (FIELD, SELECT, BUTTON, STRIP):
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
    # Enter in the password logs in; Enter in a typed user name moves on.
    assert MAIN.count("onAccepted: container.login()") == 1
    assert "onAccepted: container.focusCredentials()" in MAIN
    assert "onClicked: container.login()" in MAIN
    assert "sddm.login(user, password_input_box.text, container.sessionIndex(session.index))" in MAIN
    for key in ("Qt.Key_Return", "Qt.Key_Enter", "Qt.Key_Space"):
        assert key in BUTTON
        assert key in SELECT
        assert key in STRIP


def test_channels_are_keyboard_operable():
    for key in ("Qt.Key_Left", "Qt.Key_Right", "Qt.Key_Home", "Qt.Key_End"):
        assert key in STRIP, key
    # Right-to-left layouts flip Left/Right.
    assert "Qt.RightToLeft" in STRIP
    # Typing on the strip goes to the password: never lost.
    assert "strip.typed(event.text)" in STRIP
    assert "container.route(text)" in MAIN
    assert "onHandOff: container.focusCredentials()" in MAIN


def test_lists_are_keyboard_operable_and_return_focus():
    assert "Qt.Key_Escape" in LIST
    assert "list.trigger.forceActiveFocus()" in LIST
    # A closed list drops its sub-focus and stops taking keys.
    assert "view.focus = false;" in LIST and "enabled: list.open" in LIST
    hide = LIST.split("function choose(i)", 1)[1].split("}", 1)[0]
    assert hide.index("list.hide(true)") < hide.index("list.chosen(i)")
    assert "Qt.Key_Up" in SELECT and "Qt.Key_Down" in SELECT


def test_failed_login_keeps_username_and_refocuses_password():
    handler = MAIN.split("function onLoginFailed()", 1)[1].split("}", 1)[0]
    assert "password_input_box.forceActiveFocus()" in handler
    assert "username_input_box.text" not in handler
    assert 'container.tr("loginFailed")' in handler
    # Repeated failures say which attempt this was.
    assert 'container.tr("loginFailedCount").arg(container.failures)' in handler


def test_first_keypress_is_not_swallowed():
    assert "target.text += text;" in MAIN
    assert "container.route(event.text)" in MAIN


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
    assert "readonly property var sig: Signal.palette(highContrast, light)" in MAIN


def test_focus_is_visible_ring_plus_registration_tick():
    for text in (FIELD, SELECT, BUTTON, STRIP):
        assert "border.width: 2" in text and ".sig.focus" in text
        assert "width: 10\n        height: 2" in text


def test_reduced_motion_is_honoured():
    assert 'property bool reducedMotion: config.reducedMotion == "true"' in MAIN
    for text in (MAIN, FIELD, SELECT, BUTTON, LIST, STRIP):
        for call in re.findall(r"Signal\.(?:duration|fadeDuration)\([^)]*\)", text):
            assert "reducedMotion" in call, call


def test_login_failure_line_is_readable_and_has_icon_and_word():
    # greeter#45: the failure line was ~9 px. It must keep a >= 13 px floor,
    # an alert glyph and the localised word, never colour alone.
    assert "font.pixelSize: Math.max(13, Signal.TYPE.normal * login_container.s)" in MAIN
    assert '"alert-triangle"' in MAIN
    assert 'container.tr("loginFailed")' in MAIN
    assert "Accessible.AlertMessage" in MAIN


def test_experimental_sessions_are_listed_last_and_never_default():
    # greeter#45: stable sessions first (Hornero, then Hyprland, then others),
    # experimental last with a word chip; the default is never experimental.
    assert "id: sessionChoices" in MAIN
    assert "(a.experimental ? 2 : 0)" in MAIN
    assert "/hornero/i.test(a.name)" in MAIN
    assert "/hyprland/i.test(a.name)" in MAIN
    assert "!rows[last].experimental" in MAIN
    assert "model: sessionChoices" in MAIN
    assert "index: container.sessionDefault" in MAIN
    chips = (REPO_ROOT / "components" / "ChoiceList.qml").read_text(encoding="utf-8")
    assert 'Strings.t(list.lang, "experimental")' in chips


def test_greetd_login_failure_and_session_parity():
    # greeter#45 parity in greetd: readable >= 13 px error line with glyph,
    # alert role, empty-user guard, shared daypart helper, and EXPERIMENTAL chip.
    assert "Math.max(13, Signal.TYPE.normal * s)" in GREETD_MAIN
    assert '"alert-triangle"' in GREETD_MAIN
    assert '"info-circle"' in GREETD_MAIN
    assert "Accessible.AlertMessage" in GREETD_MAIN
    assert 'tr("loginFailed")' in GREETD_MAIN
    assert 'tr("loginFailedCount").arg(backend.failedAttempts)' in GREETD_MAIN
    assert 'tr("noUser")' in GREETD_MAIN
    assert "Strings.daypart(" in GREETD_MAIN
    assert "currentSessionExperimental" in GREETD_MAIN
    assert 'tr("experimental")' in GREETD_MAIN


def test_honest_error_states():
    # No sessions: said in words and the log-in button is disabled.
    assert "readonly property bool noSessions: sessionMirror.count === 0" in MAIN
    assert 'container.tr("noSessions")' in MAIN
    assert "enabled: !container.noSessions && !container.signingIn" in MAIN
    # A daemon that never answers is reported after a timeout.
    assert 'container.tr("noResponse")' in MAIN and "id: loginWatch" in MAIN
    # Daemon information messages are shown, Caps Lock is announced.
    assert "function onInformationMessage(message)" in MAIN
    assert "keyboard.capsLock" in MAIN and 'container.tr("capsLock")' in MAIN
    # Typed user name required before signing in.
    assert 'container.tr("noUser")' in MAIN


def test_power_actions_ask_first_and_escape_cancels():
    assert 'onClicked: container.requestPower("suspend")' in MAIN
    assert 'onClicked: container.requestPower("restart")' in MAIN
    assert 'onClicked: container.requestPower("shutdown")' in MAIN
    # Only the confirmation (or confirmPower=false) runs the action, and
    # the safe choice has focus when the question appears.
    assert MAIN.count("container.runPower(") == 2
    assert "onClicked: container.runPower(container.pendingPower)" in MAIN
    request = MAIN.split("function requestPower(kind)", 1)[1].split("\n    }\n", 1)[0]
    assert "confirm_cancel.forceActiveFocus()" in request
    assert "Keys.onEscapePressed: container.cancelPower()" in MAIN
    for call in ("sddm.suspend()", "sddm.reboot()", "sddm.powerOff()"):
        assert MAIN.count(call) == 1, call
        assert call in MAIN.split("function runPower(kind)", 1)[1].split("function cancelPower", 1)[0]


def test_secondary_outputs_get_a_quiet_plate():
    assert "typeof primaryScreen" in MAIN
    assert "visible: !container.isPrimary" in MAIN
    assert MAIN.count("visible: container.isPrimary") >= 2
    assert 'container.tr("secondary")' in MAIN
