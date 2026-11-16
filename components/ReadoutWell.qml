// ReadoutWell — a sunken instrument readout (Signal Visual Language §6.3).
//
// Mono eyebrow above a Plex Sans Condensed Medium value with an optional
// mono unit, in a `sunken` well with a 1 px `rule` border. Optional static
// scanlines (§10: 1 px every 3 px, ink at 4 %, clipped to the well) mark
// it as an instrument; they never move.
import QtQuick
import "Signal.js" as Signal

Rectangle {
    id: well

    property var sig: Signal.NIGHT
    property string eyebrow: ""
    property string value: ""
    property string unit: ""
    property color valueColor: sig.ink
    property real fontScale: 1.0
    property bool scanlines: true

    implicitWidth: Math.max(label.implicitWidth, valueRow.implicitWidth) + 2 * Signal.SPACING.normal * fontScale
    implicitHeight: label.height + valueRow.height + 18 * fontScale
    color: sig.sunken
    radius: Signal.RADIUS.small
    border.width: 1
    border.color: sig.rule
    clip: true

    Accessible.role: Accessible.StaticText
    Accessible.name: well.eyebrow + " " + well.value + " " + well.unit

    Item {
        anchors.fill: parent
        anchors.margins: 1
        visible: well.scanlines
        clip: true
        Accessible.ignored: true

        Repeater {
            model: Math.ceil(well.height / 3)
            Rectangle {
                required property int index
                y: index * 3
                width: parent.width
                height: 1
                color: Signal.alpha(well.sig.ink, 0.04)
            }
        }
    }

    Text {
        id: label
        x: Signal.SPACING.normal * well.fontScale
        y: 7 * well.fontScale
        text: well.eyebrow.toUpperCase()
        color: well.sig.inkMuted
        font.family: Signal.FONT_MONO
        font.pixelSize: Signal.TYPE.small * well.fontScale
        font.letterSpacing: Signal.TYPE.small * well.fontScale * 0.08
    }

    Row {
        id: valueRow
        x: label.x
        anchors.top: label.bottom
        anchors.topMargin: 2 * well.fontScale
        spacing: 6 * well.fontScale

        Text {
            id: valueText
            text: well.value
            color: well.valueColor
            font.family: Signal.FONT_DISPLAY
            font.weight: Font.Medium
            font.pixelSize: 24 * well.fontScale
            font.features: {
                "tnum": 1
            }
        }

        Text {
            anchors.baseline: valueText.baseline
            visible: well.unit !== ""
            text: well.unit
            color: well.sig.inkMuted
            font.family: Signal.FONT_MONO
            font.pixelSize: Signal.TYPE.normal * well.fontScale
        }
    }
}
