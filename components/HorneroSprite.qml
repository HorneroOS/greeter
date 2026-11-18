// HorneroSprite — Javi, the hornero, as the shell's small pixel sprite
// (HorneroOS/shell components/atmosphere/HorneroSprite.qml, visual language
// §17.2), so the greeter greets with the same bird as the lock screen.
// Drawn once from a character grid in palette colours: back and tail in
// signal warmed toward alert, belly in ink (paper tint on Day), the beak in
// signal, a blush cheek. Integer pixel size keeps it crisp. It blinks every
// ~7 s unless motion is reduced; nothing else moves.
//
// Decorative: hidden from assistive technology.
import QtQuick
import "Signal.js" as Signal

Item {
    id: root

    property var sig: Signal.NIGHT
    property bool light: false
    property int pixel: 3
    property bool reducedMotion: false
    // Pose: "perch" (default) or "sleep" (closed eye).
    property string pose: "perch"
    property bool blinkNow: false

    readonly property var rows: ["....bbbb........", "...bbbbbb.......", "..bbbbbbbb......", "..bbbEbbbbkk....", "..bbbbbbbbkkk...", "..bbbPbbbbk.....", ".wbbbbbbbbc.....", "wwbbbbbbbccc....", "wwwbbbbbbcccc...", ".wwwbbbbbccc....", "..wwbbbbbcc.....", "...tbbbbbc......", "....t.l.l.......", "tttttttttttttttt"]
    readonly property int cols: 16
    readonly property color cBack: Qt.tint(sig.signal, Signal.alpha(sig.alert, 0.32))
    readonly property var colours: ({
            "b": root.cBack,
            "w": Qt.darker(root.cBack, 1.35),
            "t": Qt.darker(root.cBack, 1.15),
            "c": root.light ? Qt.tint(root.sig.panel, Signal.alpha(root.sig.signal, 0.3)) : root.sig.ink,
            "k": root.sig.signal,
            "E": root.sig.ground,
            "P": Qt.tint(root.sig.alert, Signal.alpha(root.sig.ink, 0.25)),
            "l": root.sig.inkMuted
        })
    readonly property bool eyeClosed: root.pose === "sleep" || root.blinkNow

    implicitWidth: root.cols * root.pixel
    implicitHeight: root.rows.length * root.pixel
    Accessible.ignored: true

    onEyeClosedChanged: canvas.requestPaint()
    onColoursChanged: canvas.requestPaint()

    Timer {
        // A slow blink every ~7 s; never when motion is reduced.
        interval: 7000
        running: root.visible && !root.reducedMotion && root.pose === "perch"
        repeat: true
        onTriggered: {
            root.blinkNow = true;
            blinkEnd.restart();
        }
    }

    Timer {
        id: blinkEnd

        interval: 140
        onTriggered: root.blinkNow = false
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        renderTarget: Canvas.Image
        antialiasing: false
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var px = root.pixel;
            for (var y = 0; y < root.rows.length; y++) {
                var row = root.rows[y];
                for (var x = 0; x < row.length; x++) {
                    var ch = row[x];
                    if (ch === ".")
                        continue;
                    var colour = root.colours[ch];
                    if (ch === "E" && root.eyeClosed)
                        colour = root.colours["b"];
                    ctx.fillStyle = colour;
                    ctx.fillRect(x * px, y * px, px, px);
                }
            }
            if (root.eyeClosed) {
                ctx.fillStyle = root.colours["E"];
                ctx.fillRect(5 * px, 3 * px + px * 0.5, px, Math.max(1, px * 0.4));
            }
        }
    }
}
