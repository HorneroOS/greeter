// SignalSelect — labelled value selector (session, keyboard layout).
//
// Closed: a sunken well with a mono eyebrow, the current value and a
// chevron. Up/Down step through values without opening; Return, Enter,
// Space or Alt+Down open the anchored ChoiceList. Focus is a 2 px focus
// ring plus the registration tick (RFC 0001 §2), never a glow.
import QtQuick
import "Signal.js" as Signal

FocusScope {
    id: select

    property var sig: Signal.NIGHT
    property var model: null
    property string textRole: ""
    property int index: 0
    property string eyebrow: ""
    property string accessibleName: eyebrow
    property real fontScale: 1.0
    property bool opensUp: false
    property bool reducedMotion: false
    property string lang: "en"
    readonly property int count: values.count
    readonly property string currentText: values.count > 0 && values.itemAt(Math.max(0, Math.min(index, values.count - 1))) ? values.itemAt(Math.max(0, Math.min(index, values.count - 1))).text : ""
    readonly property bool popupOpen: popup.open

    signal activated(int index)

    function openList() {
        select.forceActiveFocus();
        popup.show();
    }

    function choose(i) {
        if (i < 0 || i >= values.count)
            return;
        select.index = i;
        select.activated(i);
    }

    implicitHeight: 52 * fontScale
    z: popup.open ? 10 : 0
    activeFocusOnTab: true

    Accessible.role: Accessible.ComboBox
    Accessible.name: select.accessibleName
    Accessible.description: select.currentText
    Accessible.focusable: true
    Accessible.onPressAction: popup.show()

    // Hidden value mirror: resolves the display text for any index without
    // depending on the popup having instantiated its delegates.
    Item {
        visible: false
        Repeater {
            id: values
            model: select.model
            delegate: Item {
                required property int index
                required property var model
                property var modelData: model.modelData
                readonly property string text: popup.textAt(index, modelData, model)
            }
        }
    }

    Rectangle {
        id: well
        anchors.fill: parent
        color: popup.open || mouse.containsMouse ? select.sig.raised : select.sig.sunken
        radius: Signal.RADIUS.small
        border.width: 1
        border.color: select.activeFocus || popup.open ? select.sig.focus : select.sig.ruleStrong

        Behavior on color {
            ColorAnimation {
                duration: Signal.fadeDuration("quick", select.reducedMotion)
            }
        }

        Text {
            id: eyebrowText
            anchors.left: parent.left
            anchors.leftMargin: Signal.SPACING.normal
            anchors.top: parent.top
            anchors.topMargin: 7 * select.fontScale
            text: select.eyebrow.toUpperCase()
            color: select.sig.inkMuted
            font.family: Signal.FONT_MONO
            font.pixelSize: Signal.TYPE.small * select.fontScale
            font.letterSpacing: Signal.TYPE.small * select.fontScale * 0.08
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Signal.SPACING.normal
            anchors.right: chevron.left
            anchors.rightMargin: Signal.SPACING.smaller
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7 * select.fontScale
            text: select.currentText !== "" ? select.currentText : "—"
            elide: Text.ElideRight
            color: select.sig.ink
            font.family: Signal.FONT_SANS
            font.pixelSize: Signal.TYPE.larger * select.fontScale
        }

        Glyph {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: Signal.SPACING.normal
            anchors.verticalCenter: parent.verticalCenter
            name: select.opensUp ? "chevron-up" : "chevron-down"
            size: 16 * select.fontScale
            color: select.activeFocus ? select.sig.cue : select.sig.inkMuted
        }
    }

    // Open state: 2 px signal underline on the edge facing the list.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: select.opensUp ? 0 : parent.height - 2
        height: 2
        color: select.sig.signal
        visible: popup.open
    }

    // Focus ring: 2 px focus colour, 2 px outside the control boundary.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Signal.RADIUS.small + 2
        color: "transparent"
        border.width: 2
        border.color: select.sig.focus
        visible: select.activeFocus && !popup.open
    }

    // Registration tick on the leading top corner while focused.
    Rectangle {
        x: 0
        y: -6
        width: 10
        height: 2
        color: select.sig.signal
        visible: select.activeFocus
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (popup.open) {
                popup.hide(true);
            } else {
                select.forceActiveFocus();
                popup.show();
            }
        }
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier)) {
            popup.show();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            popup.show();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            select.choose(Math.min(select.index + 1, values.count - 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            select.choose(Math.max(select.index - 1, 0));
            event.accepted = true;
        }
    }

    ChoiceList {
        id: popup
        sig: select.sig
        model: select.model
        textRole: select.textRole
        currentIndex: select.index
        opensUp: select.opensUp
        reducedMotion: select.reducedMotion
        fontScale: select.fontScale
        trigger: select
        label: select.accessibleName
        lang: select.lang
        width: select.width
        x: 0
        y: select.opensUp ? -height - 4 : select.height + 4
        onChosen: function (i) {
            select.choose(i);
        }
    }
}
