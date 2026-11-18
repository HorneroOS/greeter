// HorizonField — the greeter's generative background (no image assets).
//
// A quiet Pampa horizon drawn procedurally in the active Signal palette:
// a sky of instrument ticks with a few joined "constellations", a striped
// setting sun cut by the horizon (the Hornero mark's sun-and-bars motif),
// a windmill and a wire fence on the skyline, a dial scale along the
// horizon and furrows converging on the sun. Everything is painted ONCE
// into a software Canvas image and repainted only when the size, palette
// or seed changes, so it costs nothing per frame on any GPU.
//
// The seed picks the sky (theme.conf backgroundSeed; by default the day of
// the year mixed with the host name), so each machine gets its own sky and
// it changes gently from one day to the next. Optional ambient motion is a
// single hairline that steps down the sky once per second (no animation
// clock, no continuous redraw); it is off with reduced motion.
import QtQuick
import "Signal.js" as Signal

Item {
    id: field

    property var sig: Signal.NIGHT
    property int seed: 1
    property bool highContrast: false
    property bool reducedMotion: false
    property bool ambient: true
    property real horizon: 0.72
    // Where the sun sits on the horizon (0..1 of the width).
    property real sunX: 0.74
    readonly property real u: Math.max(0.6, Math.min(2.0, Math.min(width / 1920, height / 1080)))
    readonly property real horizonY: Math.round(height * horizon)
    // Introspection for tests and the offscreen harness.
    readonly property int paints: canvas.paints
    readonly property bool scanning: scanTimer.running

    Accessible.ignored: true

    // Deterministic PRNG (mulberry32) so a seed always draws the same sky.
    function rng(seed) {
        var a = seed >>> 0;
        return function () {
            a = (a + 0x6D2B79F5) >>> 0;
            var t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    Canvas {
        id: canvas

        property int paints: 0

        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            var p = field.sig;
            var w = width;
            var h = height;
            if (w <= 0 || h <= 0)
                return;
            var u = field.u;
            var hz = field.horizonY;
            var sx = Math.round(w * field.sunX);
            var rand = field.rng(field.seed);
            var hc = field.highContrast;
            ctx.reset();

            // Ground and a faint lift of the sky toward the horizon.
            ctx.fillStyle = p.ground;
            ctx.fillRect(0, 0, w, h);
            if (!hc) {
                var sky = ctx.createLinearGradient(0, 0, 0, hz);
                sky.addColorStop(0, p.ground);
                sky.addColorStop(1, p.base);
                ctx.fillStyle = sky;
                ctx.fillRect(0, 0, w, hz);
            }

            // Constellation of instrument ticks (sky only, above the sun's
            // reach so the two never fight).
            if (!hc) {
                var marks = Math.round(w * hz / (24000 * u * u));
                for (var i = 0; i < marks; i++) {
                    var mx = Math.round(rand() * w) + 0.5;
                    var keepOut = Math.abs(mx - w / 2) < w * 0.17;
                    var my = Math.round(rand() * (hz - 40 * u)) + 0.5;
                    var kind = rand();
                    ctx.globalAlpha = (0.28 + rand() * 0.34) * (keepOut ? 0.45 : 1);
                    if (kind < 0.04) {
                        ctx.strokeStyle = p.signal;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(mx - 4 * u, my);
                        ctx.lineTo(mx + 4 * u, my);
                        ctx.moveTo(mx, my - 4 * u);
                        ctx.lineTo(mx, my + 4 * u);
                        ctx.stroke();
                    } else if (kind < 0.3) {
                        ctx.strokeStyle = p.inkFaint;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(mx - 3 * u, my);
                        ctx.lineTo(mx + 3 * u, my);
                        ctx.moveTo(mx, my - 3 * u);
                        ctx.lineTo(mx, my + 3 * u);
                        ctx.stroke();
                    } else {
                        ctx.fillStyle = p.inkFaint;
                        var d = kind > 0.85 ? 2 : 1;
                        ctx.fillRect(mx - 0.5, my - 0.5, d, d);
                    }
                }
                // Three small constellations: 4-5 ringed points joined by
                // rule hairlines, like plotted readings.
                for (var c = 0; c < 3; c++) {
                    // Constellations stay out of the centre column (clock and
                    // sign-in module): left third, right third, alternating.
                    var side = c % 2 === 0 ? 0.04 : 0.66;
                    var cx = (side + 0.28 * rand()) * w;
                    var cy = (0.08 + 0.5 * rand()) * hz;
                    var n = 4 + Math.floor(rand() * 2);
                    var pts = [];
                    for (var k = 0; k < n; k++) {
                        cx = Math.max(side * w, Math.min((side + 0.3) * w, cx + (rand() * 2 - 1) * 90 * u));
                        cy += (rand() * 2 - 1) * 50 * u;
                        pts.push([Math.round(cx) + 0.5, Math.round(Math.max(12, Math.min(hz - 60 * u, cy))) + 0.5]);
                    }
                    ctx.globalAlpha = 0.5;
                    ctx.strokeStyle = p.rule;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(pts[0][0], pts[0][1]);
                    for (k = 1; k < n; k++)
                        ctx.lineTo(pts[k][0], pts[k][1]);
                    ctx.stroke();
                    ctx.globalAlpha = 0.7;
                    ctx.strokeStyle = p.inkFaint;
                    for (k = 0; k < n; k++) {
                        ctx.beginPath();
                        ctx.arc(pts[k][0], pts[k][1], 2.5 * u, 0, 2 * Math.PI);
                        ctx.stroke();
                    }
                }
                ctx.globalAlpha = 1;
            }

            // Striped sun, half set: bands thin out toward the horizon.
            if (!hc) {
                var r = Math.round(h * 0.17);
                ctx.save();
                ctx.beginPath();
                ctx.rect(0, 0, w, hz);
                ctx.clip();
                ctx.beginPath();
                ctx.arc(sx, hz, r, 0, 2 * Math.PI);
                ctx.clip();
                ctx.fillStyle = p.signal;
                var bands = [[0, 0.4], [0.47, 0.64], [0.71, 0.82], [0.88, 0.94], [0.97, 1]];
                for (var b = 0; b < bands.length; b++) {
                    ctx.globalAlpha = 0.11 + 0.045 * b;
                    var y0 = hz - r + bands[b][0] * r;
                    ctx.fillRect(sx - r, y0, 2 * r, (bands[b][1] - bands[b][0]) * r);
                }
                ctx.restore();
                ctx.globalAlpha = 1;
            }

            // Skyline: a Pampa windmill and a wire fence, in ruleStrong.
            if (!hc) {
                ctx.strokeStyle = p.ruleStrong;
                ctx.lineWidth = 1;
                ctx.globalAlpha = 0.55;
                var wx = Math.round(w * 0.17) + 0.5;
                var th = Math.round(86 * u);
                var top = hz - th;
                ctx.beginPath();
                // Lattice tower.
                ctx.moveTo(wx - 9 * u, hz);
                ctx.lineTo(wx - 1.5 * u, top);
                ctx.moveTo(wx + 9 * u, hz);
                ctx.lineTo(wx + 1.5 * u, top);
                for (var q = 1; q < 5; q++) {
                    var ly = hz - q * th / 5;
                    var half = 9 * u - (7.5 * u) * q / 5;
                    ctx.moveTo(wx - half, ly);
                    ctx.lineTo(wx + half, ly);
                }
                // Rotor: twelve blades on a ring, tail vane to the right.
                var rr = 17 * u;
                for (var bl = 0; bl < 12; bl++) {
                    var ang = bl * Math.PI / 6;
                    ctx.moveTo(wx + Math.cos(ang) * 3 * u, top + Math.sin(ang) * 3 * u);
                    ctx.lineTo(wx + Math.cos(ang) * rr, top + Math.sin(ang) * rr);
                }
                ctx.moveTo(wx, top);
                ctx.lineTo(wx + 30 * u, top);
                ctx.lineTo(wx + 30 * u, top - 7 * u);
                ctx.lineTo(wx + 22 * u, top);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(wx, top, rr, 0, 2 * Math.PI);
                ctx.stroke();

                // Fence posts with two wires, fading off toward the left.
                var fx0 = Math.round(w * 0.22);
                var fx1 = Math.round(w * 0.44);
                var step = Math.round(42 * u);
                for (var fx = fx0; fx <= fx1; fx += step) {
                    ctx.globalAlpha = 0.5;
                    ctx.beginPath();
                    ctx.moveTo(fx + 0.5, hz);
                    ctx.lineTo(fx + 0.5, hz - 12 * u);
                    ctx.stroke();
                }
                ctx.globalAlpha = 0.35;
                ctx.beginPath();
                ctx.moveTo(fx0, Math.round(hz - 9 * u) + 0.5);
                ctx.lineTo(fx1, Math.round(hz - 9 * u) + 0.5);
                ctx.moveTo(fx0, Math.round(hz - 5 * u) + 0.5);
                ctx.lineTo(fx1, Math.round(hz - 5 * u) + 0.5);
                ctx.stroke();
                ctx.globalAlpha = 1;
            }

            // Horizon line with a dial scale, like the slate's tuning well.
            ctx.globalAlpha = hc ? 1 : 0.7;
            ctx.fillStyle = p.ruleStrong;
            ctx.fillRect(0, hz, w, 1);
            if (!hc) {
                var tick = Math.max(8, Math.round(14 * u));
                for (var t = 0, ti = 0; t < w; t += tick, ti++) {
                    var major = ti % 5 === 0;
                    ctx.globalAlpha = major ? 0.5 : 0.28;
                    ctx.fillRect(Math.round(t), hz + 1, 1, Math.round((major ? 9 : 4) * u));
                }
            }

            // Furrows: rows that tighten toward the horizon and lines that
            // converge on the sun.
            if (!hc) {
                ctx.strokeStyle = p.rule;
                ctx.lineWidth = 1;
                var rows = 9;
                var depth = h - hz;
                for (var fr = 1; fr <= rows; fr++) {
                    var fy = Math.round(hz + depth * (fr * fr) / (rows * rows)) + 0.5;
                    ctx.globalAlpha = 0.25 + 0.5 * fr / rows;
                    ctx.beginPath();
                    ctx.moveTo(0, fy);
                    ctx.lineTo(w, fy);
                    ctx.stroke();
                }
                ctx.save();
                ctx.beginPath();
                ctx.rect(0, hz + 1, w, depth);
                ctx.clip();
                ctx.globalAlpha = 0.4;
                ctx.beginPath();
                var spread = w / 7;
                for (var fl = -9; fl <= 9; fl++) {
                    ctx.moveTo(sx, hz);
                    ctx.lineTo(sx + fl * spread, h);
                }
                ctx.stroke();
                ctx.restore();
                ctx.globalAlpha = 1;
            }
            paints++;
        }
    }

    onSigChanged: canvas.requestPaint()
    onSeedChanged: canvas.requestPaint()
    onHighContrastChanged: canvas.requestPaint()

    // Ambient scan: one hairline stepping down the sky at 1 Hz, wrapping at
    // the horizon (about three minutes per pass). No animation runs.
    Item {
        id: scan

        property int step: 0
        readonly property int steps: 180

        visible: scanTimer.running
        width: field.width
        height: Math.round(28 * field.u)
        y: Math.round((field.horizonY - height) * step / steps)

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Signal.alpha(field.sig.signal, 0)
                }
                GradientStop {
                    position: 1
                    color: Signal.alpha(field.sig.signal, 0.05)
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Signal.alpha(field.sig.signal, 0.16)
        }
    }

    Timer {
        id: scanTimer

        interval: 1000
        repeat: true
        running: field.ambient && !field.reducedMotion && !field.highContrast && field.visible
        onTriggered: scan.step = (scan.step + 1) % scan.steps
    }
}
