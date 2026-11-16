// DiagonalHatch — the La Plata 45° diagonal (RFC 0001 §2), as a band of
// hairline strokes. Brand surfaces only (greeter rails and the sign-in
// header); never inside controls.
import QtQuick

Item {
    id: hatch

    property color color: "#F2A33A"
    property int pitch: 6
    property real stroke: 1.5

    clip: true
    Accessible.ignored: true

    Repeater {
        model: Math.ceil((hatch.width + hatch.height) / hatch.pitch) + 1

        Rectangle {
            required property int index
            width: hatch.stroke
            height: (hatch.height + hatch.width) * 1.5
            x: index * hatch.pitch - hatch.height
            y: -hatch.width * 0.25
            color: hatch.color
            antialiasing: true
            transformOrigin: Item.Center
            rotation: 45
        }
    }
}
