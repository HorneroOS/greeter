// ChannelStrip — user accounts as instrument channels.
//
// Each account is a channel tile: a mono "CH 01" eyebrow, the avatar (or
// the initial in a sunken well when the account has no face of its own)
// and the display name. The tuned channel is a signalWell tile with a 2 px
// signal on-air bar on top; with focus it also gets the 2 px focus ring.
// An optional last tile, "Other", switches to a typed user name.
//
// One Tab stop: Left/Right (Up/Down too) tune, Home/End jump, Enter or
// Space hand over to the password. Printable keys are forwarded through
// `typed` so the first keypress is never lost. The strip is one accessible
// list whose description is always the tuned channel, read on every change.
import QtQuick
import "Signal.js" as Signal
import "Strings.js" as Strings

FocusScope {
    id: strip

    property var sig: Signal.NIGHT
    property string lang: "en"
    // [{name, realName, icon}]
    property var users: []
    property bool allowOther: true
    property int currentIndex: 0
    property real fontScale: 1.0
    property bool reducedMotion: false
    readonly property int count: users.length + (allowOther ? 1 : 0)
    readonly property bool otherSelected: allowOther && currentIndex === users.length
    // Tiles share the strip width up to 116 px each (scaled); past a
    // 80 px floor the strip scrolls instead of squeezing names.
    readonly property real tileWidth: count > 0 ? Math.round(Math.max(80 * fontScale, Math.min(116 * fontScale, (width - (count - 1) * Signal.SPACING.smaller) / count))) : 0
    readonly property real tileHeight: Math.round(96 * fontScale)

    signal tuned(int index)
    signal handOff
    signal typed(string text)

    function tune(i) {
        if (count === 0)
            return;
        var next = Math.max(0, Math.min(count - 1, i));
        if (next !== currentIndex) {
            currentIndex = next;
            tuned(next);
        }
    }

    function labelAt(i) {
        if (i === users.length)
            return Strings.t(lang, "channel.other");
        var u = users[i];
        return u ? (u.realName && u.realName !== "" ? u.realName : u.name) : "";
    }

    function hasOwnFace(icon) {
        // SDDM hands every account the shared default face; only a real
        // per-user picture is worth showing over the initial.
        var s = String(icon || "");
        return s !== "" && s.indexOf("faces/.face.icon") < 0 && s.indexOf("default.face.icon") < 0;
    }

    implicitHeight: tileHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.List
    Accessible.name: Strings.t(lang, "a11y.channels")
    Accessible.description: Strings.t(lang, "a11y.channel").arg(currentIndex + 1).arg(count).arg(labelAt(currentIndex)) + ". " + Strings.t(lang, "a11y.channelsHelp")
    Accessible.focusable: true

    Keys.onPressed: function (event) {
        var k = event.key;
        var back = Qt.application.layoutDirection === Qt.RightToLeft;
        if (k === Qt.Key_Right || k === Qt.Key_Down) {
            strip.tune(strip.currentIndex + ((k === Qt.Key_Right && back) ? -1 : 1));
            event.accepted = true;
        } else if (k === Qt.Key_Left || k === Qt.Key_Up) {
            strip.tune(strip.currentIndex - ((k === Qt.Key_Left && back) ? -1 : 1));
            event.accepted = true;
        } else if (k === Qt.Key_Home) {
            strip.tune(0);
            event.accepted = true;
        } else if (k === Qt.Key_End) {
            strip.tune(strip.count - 1);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            strip.handOff();
            event.accepted = true;
        } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
            strip.typed(event.text);
            event.accepted = true;
        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: tiles.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true
        // Keep the tuned channel in view.
        contentX: Math.max(0, Math.min(contentWidth - width, (strip.currentIndex + 1) * (strip.tileWidth + Signal.SPACING.smaller) - width))

        Behavior on contentX {
            NumberAnimation {
                duration: Signal.duration("short", strip.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Signal.CURVE.standard
            }
        }

        Row {
            id: tiles

            y: 0
            spacing: Signal.SPACING.smaller

            Repeater {
                model: strip.count

                Rectangle {
                    id: tile

                    required property int index
                    readonly property bool other: index === strip.users.length
                    readonly property var user: other ? null : strip.users[index]
                    readonly property bool tunedIn: index === strip.currentIndex
                    readonly property string label: strip.labelAt(index)

                    width: strip.tileWidth
                    height: strip.tileHeight
                    radius: Signal.RADIUS.small
                    color: tunedIn ? strip.sig.signalWell : (hover.containsMouse ? strip.sig.raised : strip.sig.sunken)
                    border.width: 1
                    border.color: tunedIn ? strip.sig.signal : strip.sig.rule

                    Behavior on color {
                        ColorAnimation {
                            duration: Signal.fadeDuration("quick", strip.reducedMotion)
                        }
                    }

                    // On-air bar: the tuned channel.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 2
                        color: strip.sig.signal
                        visible: tile.tunedIn
                    }

                    Text {
                        id: chLabel

                        anchors.left: parent.left
                        anchors.leftMargin: Signal.SPACING.smaller
                        anchors.top: parent.top
                        anchors.topMargin: Math.round(8 * strip.fontScale)
                        text: Strings.t(strip.lang, "channel") + " " + (tile.index + 1 < 10 ? "0" : "") + (tile.index + 1)
                        color: tile.tunedIn ? strip.sig.onSignalWell : strip.sig.inkMuted
                        font.family: Signal.FONT_MONO
                        font.pixelSize: Signal.TYPE.small * strip.fontScale
                        font.letterSpacing: Signal.TYPE.small * strip.fontScale * 0.08
                        font.features: {
                            "tnum": 1
                        }
                    }

                    // Tally dot: lit on the tuned channel.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: Signal.SPACING.smaller
                        anchors.verticalCenter: chLabel.verticalCenter
                        width: Math.round(6 * strip.fontScale)
                        height: width
                        radius: width / 2
                        color: tile.tunedIn ? strip.sig.signal : "transparent"
                        border.width: 1
                        border.color: tile.tunedIn ? strip.sig.signal : strip.sig.ruleStrong
                    }

                    Rectangle {
                        id: face

                        anchors.left: parent.left
                        anchors.leftMargin: Signal.SPACING.smaller
                        anchors.top: chLabel.bottom
                        anchors.topMargin: Math.round(6 * strip.fontScale)
                        width: Math.round(30 * strip.fontScale)
                        height: width
                        radius: Signal.RADIUS.small
                        color: strip.sig.base
                        border.width: 1
                        border.color: tile.tunedIn ? strip.sig.signal : strip.sig.ruleStrong
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: !tile.other && avatar.status !== Image.Ready
                            text: tile.label.length > 0 ? tile.label.charAt(0).toUpperCase() : "?"
                            color: tile.tunedIn ? strip.sig.signal : strip.sig.ink
                            font.family: Signal.FONT_DISPLAY
                            font.weight: Font.Medium
                            font.pixelSize: Signal.TYPE.large * strip.fontScale
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: tile.other
                            name: "user-plus"
                            size: Math.round(16 * strip.fontScale)
                            color: tile.tunedIn ? strip.sig.signal : strip.sig.inkMuted
                        }

                        Image {
                            id: avatar

                            anchors.fill: parent
                            anchors.margins: 1
                            visible: status === Image.Ready
                            source: !tile.other && tile.user && strip.hasOwnFace(tile.user.icon) ? tile.user.icon : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 96
                            sourceSize.height: 96
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Signal.SPACING.smaller
                        anchors.right: parent.right
                        anchors.rightMargin: Signal.SPACING.smaller
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(8 * strip.fontScale)
                        text: tile.label
                        elide: Text.ElideRight
                        color: tile.tunedIn ? strip.sig.onSignalWell : strip.sig.ink
                        font.family: Signal.FONT_SANS
                        font.weight: tile.tunedIn ? Font.DemiBold : Font.Normal
                        font.pixelSize: Signal.TYPE.normal * strip.fontScale
                    }

                    // Focus ring on the tuned tile while the strip has focus.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: Signal.RADIUS.small + 2
                        color: "transparent"
                        border.width: 2
                        border.color: strip.sig.focus
                        visible: tile.tunedIn && strip.activeFocus
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            strip.forceActiveFocus();
                            strip.tune(tile.index);
                            strip.handOff();
                        }
                    }
                }
            }
        }
    }

    // Registration tick on the leading top corner while focused.
    Rectangle {
        x: 0
        y: -6
        width: 10
        height: 2
        color: strip.sig.signal
        visible: strip.activeFocus
    }
}
