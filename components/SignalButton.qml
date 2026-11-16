// SignalButton — primary (signal fill), quiet (outlined) and icon buttons.
//
// Primary is the single amber action on screen (log in). Quiet buttons
// carry a glyph plus a mono label so power actions are never icon-only.
// Keyboard: Return, Enter and Space activate; focus is the 2 px focus ring
// plus the registration tick.
import QtQuick
import "Signal.js" as Signal

FocusScope {
    id: button

    property var sig: Signal.NIGHT
    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool checked: false
    property bool showLabel: true
    property real fontScale: 1.0
    property bool reducedMotion: false
    property string accessibleName: text
    property string accessibleDescription: ""
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked

    implicitHeight: (primary ? 52 : 32) * fontScale
    implicitWidth: row.implicitWidth + 2 * (primary ? Signal.SPACING.larger : Signal.SPACING.smaller)
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: button.accessibleName
    Accessible.description: button.accessibleDescription
    Accessible.focusable: true
    Accessible.onPressAction: button.clicked()

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Signal.RADIUS.small
        color: {
            if (button.primary)
                return button.pressed ? Qt.darker(button.sig.signal, 1.12) : (button.hovered ? Qt.lighter(button.sig.signal, 1.06) : button.sig.signal);
            if (button.checked)
                return button.sig.signalWell;
            return button.pressed ? button.sig.lifted : (button.hovered ? button.sig.raised : "transparent");
        }
        // Quiet buttons are rail segments (Signal Visual Language §4, §8):
        // no boundary at rest, raised on hover, lifted when pressed.
        border.width: button.checked ? 1 : 0
        border.color: button.sig.signal

        Behavior on color {
            ColorAnimation {
                duration: Signal.fadeDuration("quick", button.reducedMotion)
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Signal.SPACING.smaller
        layoutDirection: button.primary ? Qt.RightToLeft : Qt.LeftToRight

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: button.glyph
            size: (button.primary ? 18 : 16) * button.fontScale
            color: button.primary ? button.sig.onSignal : (button.checked ? button.sig.onSignalWell : (button.activeFocus || button.hovered ? button.sig.ink : button.sig.inkMuted))
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.showLabel && button.text !== ""
            text: button.primary ? button.text : button.text.toUpperCase()
            color: button.primary ? button.sig.onSignal : (button.checked ? button.sig.onSignalWell : (button.activeFocus || button.hovered ? button.sig.ink : button.sig.inkMuted))
            font.family: button.primary ? Signal.FONT_SANS : Signal.FONT_MONO
            font.weight: button.primary ? Font.DemiBold : Font.Normal
            font.pixelSize: (button.primary ? Signal.TYPE.larger : Signal.TYPE.small) * button.fontScale
            font.letterSpacing: button.primary ? 0.2 : Signal.TYPE.small * button.fontScale * 0.08
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Signal.RADIUS.small + 2
        color: "transparent"
        border.width: 2
        border.color: button.sig.focus
        visible: button.activeFocus
    }

    Rectangle {
        x: 0
        y: -6
        width: 10
        height: 2
        color: button.sig.signal
        visible: button.activeFocus && !button.primary
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            button.clicked();
            event.accepted = true;
        }
    }
}
