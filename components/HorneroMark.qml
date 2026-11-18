// HorneroMark — the Hornero symbolic mark (HorneroOS/config assets
// mark.svg: a setting-sun disc cut by two horizon bars), drawn in any
// palette colour. Same geometry as the shell's reload-cover slate, so the
// greeter, lock and stand-by slate share one ident. Repaints only when its
// size or colour changes.
import QtQuick

Canvas {
    id: root

    property real size: 48
    property color color: "#F2A33A"

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    Accessible.ignored: true

    onColorChanged: requestPaint()
    onSizeChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        var k = width / 24;
        ctx.reset();
        ctx.save();
        ctx.beginPath();
        ctx.arc(12 * k, 12 * k, 9.5 * k, 0, 2 * Math.PI);
        ctx.clip();
        ctx.fillStyle = root.color;
        // Same bands as mark.svg's viewBox 0 0 24 24.
        ctx.fillRect(0, 2.5 * k, 24 * k, 5.85 * k);
        ctx.fillRect(0, 10.1 * k, 24 * k, 3.8 * k);
        ctx.fillRect(0, 15.65 * k, 24 * k, 5.85 * k);
        ctx.restore();
    }
}
