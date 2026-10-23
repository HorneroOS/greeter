import QtQuick

Item {
    id: control

    property real accessibilityScale: 1.0
    property bool highContrast: false
    property bool checked: false
    property color accentColor: "#e0342c"
    property bool hovered: mouseArea.containsMouse

    signal toggleRequested()

    width: 40 * accessibilityScale
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: "Toggle on-screen keyboard"
    Accessible.description: checked ? "Hide on-screen keyboard" : "Show on-screen keyboard"
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: control.toggleRequested()

    Rectangle {
        anchors.fill: parent
        color: control.checked ? "#393939" : "transparent"
        border.color: control.highContrast ? "#ffffff" : (control.activeFocus || control.hovered ? control.accentColor : "transparent")
        border.width: control.highContrast || control.activeFocus ? 1 : 0

        Text {
            anchors.centerIn: parent
            text: "⌨"
            color: control.highContrast ? "#ffffff" : control.accentColor
            font.pixelSize: 14 * control.accessibilityScale
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggleRequested()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            control.toggleRequested();
            event.accepted = true;
        }
    }
}
