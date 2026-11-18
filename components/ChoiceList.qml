// ChoiceList — anchored list surface for SignalSelect and the user chooser.
//
// A floating popout (Signal Visual Language §7.1): 4 px from its trigger,
// all four borders, and a 2 px signal notch on the edge facing the trigger
// so its origin reads with animations off. Opens with 6 px settleFast
// travel plus an enter fade; takes keyboard focus while open, and hands focus back
// to the trigger on Escape or selection. Up/Down move, Home/End jump,
// Return/Enter/Space choose.
import QtQuick
import "Signal.js" as Signal
import "Strings.js" as Strings

Rectangle {
    id: list

    property var sig: Signal.NIGHT
    property var model: null
    property string textRole: ""
    property int currentIndex: 0
    property bool opensUp: false
    property bool open: false
    property bool reducedMotion: false
    property real fontScale: 1.0
    property Item trigger: null
    property string label: ""
    property string lang: "en"

    signal chosen(int index)

    function textAt(i, modelData, model) {
        if (list.textRole === "")
            return String(modelData);
        if (model && model[list.textRole] !== undefined)
            return model[list.textRole];
        if (modelData && modelData[list.textRole] !== undefined)
            return modelData[list.textRole];
        return "";
    }

    function show() {
        view.currentIndex = Math.max(0, list.currentIndex);
        list.open = true;
        view.forceActiveFocus();
    }

    function hide(returnFocus) {
        list.open = false;
        // Release the list's sub-focus first: otherwise the trigger's
        // FocusScope hands active focus straight back to the hidden view.
        view.focus = false;
        if (returnFocus && list.trigger)
            list.trigger.forceActiveFocus();
    }

    // Close (restoring trigger focus) before announcing the choice, so the
    // caller's onChosen can move focus elsewhere.
    function choose(i) {
        list.hide(true);
        list.chosen(i);
    }

    height: Math.min(view.contentHeight, 6 * 36 * fontScale) + 2
    color: sig.lifted
    radius: Signal.RADIUS.small
    border.color: sig.ruleStrong
    border.width: 1
    z: 50
    clip: true
    visible: opacity > 0
    opacity: open ? 1 : 0
    transform: Translate {
        y: list.open ? 0 : (list.opensUp ? 6 : -6)
        Behavior on y {
            NumberAnimation {
                duration: Signal.duration("settleFast", list.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Signal.CURVE.settleFast
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Signal.fadeDuration(list.open ? "short" : "quick", list.reducedMotion)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: list.open ? Signal.CURVE.enter : Signal.CURVE.exit
        }
    }

    // Notch: continues the trigger's open-state underline.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: list.opensUp ? parent.height - 2 : 0
        height: 2
        z: 2
        color: list.sig.signal
    }

    Accessible.role: Accessible.List
    Accessible.name: list.label

    ListView {
        id: view

        anchors.fill: parent
        anchors.margins: 1
        enabled: list.open
        model: list.model
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: false
        highlightMoveDuration: 0

        delegate: Rectangle {
            id: row

            required property int index
            required property var model
            property var modelData: row.model.modelData
            readonly property string text: list.textAt(row.index, row.modelData, row.model)
            readonly property bool selected: row.index === list.currentIndex

            width: ListView.view.width
            height: 36 * list.fontScale
            color: row.selected ? list.sig.signalWell : (ListView.isCurrentItem ? list.sig.raised : "transparent")

            Accessible.role: Accessible.ListItem
            Accessible.name: row.text
            Accessible.selected: row.selected

            Rectangle {
                // On-air bar: the chosen value, 2 px signal on the content edge.
                width: 2
                height: parent.height
                anchors.left: parent.left
                color: list.sig.signal
                visible: row.selected
            }

            Rectangle {
                // Keyboard cursor inside the list: 2 px focus ring, inset.
                anchors.fill: parent
                anchors.margins: 2
                color: "transparent"
                border.width: 2
                border.color: list.sig.focus
                radius: Signal.RADIUS.small
                visible: row.ListView.isCurrentItem && view.activeFocus
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Signal.SPACING.normal
                anchors.right: chip.visible ? chip.left : (tick.visible ? tick.left : parent.right)
                anchors.rightMargin: Signal.SPACING.smaller
                anchors.verticalCenter: parent.verticalCenter
                text: row.text
                elide: Text.ElideRight
                color: row.selected ? list.sig.onSignalWell : list.sig.ink
                font.family: Signal.FONT_SANS
                font.pixelSize: Signal.TYPE.normal * list.fontScale
            }

            // Experimental sessions carry a word chip, never colour alone.
            Rectangle {
                id: chip
                readonly property bool flagged: row.model.experimental === true
                visible: chip.flagged
                anchors.right: tick.visible ? tick.left : parent.right
                anchors.rightMargin: tick.visible ? Signal.SPACING.smaller : Signal.SPACING.normal
                anchors.verticalCenter: parent.verticalCenter
                width: chipText.width + 2 * Signal.SPACING.smaller
                height: Math.round(18 * list.fontScale)
                radius: Signal.RADIUS.small
                color: "transparent"
                border.width: 1
                border.color: list.sig.ruleStrong

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: Strings.t(list.lang, "experimental")
                    color: list.sig.inkMuted
                    font.family: Signal.FONT_MONO
                    font.pixelSize: Signal.TYPE.small * list.fontScale
                    font.letterSpacing: Signal.TYPE.small * list.fontScale * 0.08
                }
            }

            Text {
                id: tick
                anchors.right: parent.right
                anchors.rightMargin: Signal.SPACING.normal
                anchors.verticalCenter: parent.verticalCenter
                text: Strings.t(list.lang, "active")
                visible: row.selected
                color: list.sig.onSignalWell
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * list.fontScale
                font.letterSpacing: Signal.TYPE.small * list.fontScale * 0.08
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: view.currentIndex = row.index
                onClicked: list.choose(row.index)
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                list.hide(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                list.choose(view.currentIndex);
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                view.currentIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                view.currentIndex = view.count - 1;
                event.accepted = true;
            }
        }
    }
}
