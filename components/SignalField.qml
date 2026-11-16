// SignalField — labelled text well for the username and password.
//
// A mono eyebrow sits inside the sunken well above the value; the leading
// glyph names the field. Focus draws the 2 px focus ring and the signal
// registration tick (RFC 0001 §2). Password fields mask with a bullet and
// never expose their text to accessibility.
import QtQuick
import "Signal.js" as Signal

FocusScope {
    id: field

    property var sig: Signal.NIGHT
    property string eyebrow: ""
    property string glyph: ""
    property alias text: input.text
    property bool password: false
    property real fontScale: 1.0
    property bool reducedMotion: false
    property bool invalid: false
    property string trailingGlyph: ""
    property string trailingName: ""
    readonly property alias input: input

    signal accepted
    signal trailingClicked

    function selectAll() {
        input.selectAll();
    }

    implicitHeight: 52 * fontScale
    activeFocusOnTab: true

    Accessible.role: Accessible.EditableText
    Accessible.name: field.eyebrow
    Accessible.passwordEdit: field.password
    Accessible.focusable: true

    Rectangle {
        id: well
        anchors.fill: parent
        color: field.activeFocus ? field.sig.base : field.sig.sunken
        radius: Signal.RADIUS.small
        border.width: 1
        border.color: field.invalid ? field.sig.alert : (field.activeFocus ? field.sig.focus : field.sig.ruleStrong)

        Behavior on color {
            ColorAnimation {
                duration: Signal.fadeDuration("quick", field.reducedMotion)
            }
        }
    }

    Glyph {
        id: lead
        anchors.left: parent.left
        anchors.leftMargin: Signal.SPACING.normal
        anchors.verticalCenter: parent.verticalCenter
        name: field.glyph
        size: 18 * field.fontScale
        color: field.activeFocus ? field.sig.cue : field.sig.inkMuted
    }

    Text {
        id: eyebrowText
        anchors.left: lead.right
        anchors.leftMargin: Signal.SPACING.normal
        anchors.top: parent.top
        anchors.topMargin: 7 * field.fontScale
        text: field.eyebrow.toUpperCase()
        color: field.invalid ? field.sig.alert : field.sig.inkMuted
        font.family: Signal.FONT_MONO
        font.pixelSize: Signal.TYPE.small * field.fontScale
        font.letterSpacing: Signal.TYPE.small * field.fontScale * 0.08
    }

    TextInput {
        id: input
        anchors.left: lead.right
        anchors.leftMargin: Signal.SPACING.normal
        anchors.right: trailing.visible ? trailing.left : parent.right
        anchors.rightMargin: Signal.SPACING.normal
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6 * field.fontScale
        focus: true
        clip: true
        color: field.sig.ink
        selectionColor: field.sig.cueWell
        selectedTextColor: field.sig.onCueWell
        font.family: field.password && input.text.length > 0 ? Signal.FONT_MONO : Signal.FONT_SANS
        font.pixelSize: Signal.TYPE.larger * field.fontScale
        font.letterSpacing: field.password ? 2 : 0
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        passwordMaskDelay: 0
        cursorDelegate: Rectangle {
            // Steady block caret in signal amber: no blink (calm by design).
            width: 2
            color: field.sig.signal
            visible: input.activeFocus
        }
        onAccepted: field.accepted()
        Accessible.ignored: true
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: trailing.visible ? trailing.width + Signal.SPACING.smaller : 0
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.LeftButton
        onPressed: function (mouse) {
            field.forceActiveFocus();
            mouse.accepted = false;
        }
    }

    Rectangle {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 36 * field.fontScale
        height: 36 * field.fontScale
        radius: Signal.RADIUS.small
        visible: field.trailingGlyph !== ""
        color: trailingMouse.containsMouse ? field.sig.raised : "transparent"

        Glyph {
            anchors.centerIn: parent
            name: field.trailingGlyph
            size: 16 * field.fontScale
            color: field.sig.inkMuted
        }

        MouseArea {
            id: trailingMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: field.trailingClicked()
        }

        Accessible.role: Accessible.Button
        Accessible.name: field.trailingName
        Accessible.onPressAction: field.trailingClicked()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Signal.RADIUS.small + 2
        color: "transparent"
        border.width: 2
        border.color: field.sig.focus
        visible: field.activeFocus
    }

    Rectangle {
        x: 0
        y: -6
        width: 10
        height: 2
        color: field.sig.signal
        visible: field.activeFocus
    }
}
