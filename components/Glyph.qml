// Glyph — Hornero Glyphs for the greeter (RFC 0001 §3.4).
//
// The greeter cannot load the shell's assets/fonts/hornero-glyphs.ttf (it
// runs as the sddm user before any session, from its own theme directory),
// so it draws the handful of glyphs it needs as vector strokes with the
// same API: Glyph { name: "power" }. Paths are Tabler Icons outline
// geometry (MIT, (c) 2020-2024 Paweł Kuna; see NOTICE) on a 24 px grid,
// stroked at 1.75 px so they read as hairlines at 16-24 px.
import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property string name: ""
    property color color: "#ECE6DA"
    property real stroke: 1.75
    property int size: 18

    readonly property var paths: ({
            "power": "M7 6a7.75 7.75 0 1 0 10 0 M12 4l0 8",
            "refresh": "M20 11a8.1 8.1 0 0 0 -15.5 -2 M4 5v4h4 M4 13a8.1 8.1 0 0 0 15.5 2 M20 19v-4h-4",
            "keyboard": "M4 6h16a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-16a2 2 0 0 1 -2 -2v-8a2 2 0 0 1 2 -2z M6 10l0 .01 M10 10l0 .01 M14 10l0 .01 M18 10l0 .01 M6 14l0 .01 M18 14l0 .01 M10 14l4 .01",
            "arrow-right": "M5 12l14 0 M13 18l6 -6 M13 6l6 6",
            "chevron-down": "M6 9l6 6l6 -6",
            "chevron-up": "M6 15l6 -6l6 6",
            "check": "M5 12l5 5l10 -10",
            "user": "M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0 M6 21v-2a4 4 0 0 1 4 -4h4a4 4 0 0 1 4 4v2",
            "lock": "M5 13a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-6z M11 16a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M8 11v-4a4 4 0 1 1 8 0v4",
            "alert-triangle": "M12 9v4 M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0z M12 16h.01"
        })

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    visible: name !== "" && paths[name] !== undefined

    Accessible.ignored: true

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: glyph.size / 24
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: glyph.color
            strokeWidth: glyph.stroke * 24 / glyph.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: glyph.paths[glyph.name] || ""
            }
        }
    }
}
