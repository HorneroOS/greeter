// OnAirChip — the Live state (Signal Visual Language §8): `signal` fill with
// an `onSignal` mono label. When idle it is an outlined `inkMuted` chip.
//
// Luminous accent (§9): the live chip may carry a static halo in `glow` at
// 40 % alpha with a 4 px blur and no spread. It never pulses; it changes
// only when the live state changes, and is off in High Contrast.
import QtQuick
import QtQuick.Effects
import "Signal.js" as Signal

Item {
    id: chip

    property var sig: Signal.NIGHT
    property string text: ""
    property bool live: false
    property bool glow: true
    property real fontScale: 1.0

    implicitWidth: label.implicitWidth + 2 * Signal.SPACING.smaller * fontScale
    implicitHeight: label.implicitHeight + 6 * fontScale
    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: chip.text

    RectangularShadow {
        anchors.fill: face
        visible: chip.live && chip.glow
        radius: face.radius
        blur: 4
        spread: 0
        color: Signal.alpha(chip.sig.glow, 0.4)
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Signal.RADIUS.small
        color: chip.live ? chip.sig.signal : "transparent"
        border.width: chip.live ? 0 : 1
        border.color: chip.sig.ruleStrong
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.live ? chip.sig.onSignal : chip.sig.inkMuted
        font.family: Signal.FONT_MONO
        font.weight: chip.live ? Font.DemiBold : Font.Normal
        font.pixelSize: Signal.TYPE.small * chip.fontScale
        font.letterSpacing: Signal.TYPE.small * chip.fontScale * 0.08
    }
}
