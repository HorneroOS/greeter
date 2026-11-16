// DayScale — 24 h telemetry ruler under the clock.
//
// Shows the greeter's own media dayparts (theme.conf day / golden-hour /
// night windows) as segmented bands and the current time as a signal
// cursor, so the footage mood on screen is explained, not decorative.
import QtQuick
import "Signal.js" as Signal
import "MediaCatalog.js" as Catalog

Item {
    id: ruler

    property var sig: Signal.NIGHT
    property date now: new Date()
    property int dayStart: 7
    property int dayEnd: 19
    property int goldenStart: 17
    property int goldenEnd: 20
    property real fontScale: 1.0
    property bool reducedMotion: false
    property bool armed: false
    readonly property real hourWidth: width / 24
    readonly property real position: (now.getHours() + now.getMinutes() / 60) / 24

    implicitHeight: legend.y + legend.height
    Accessible.ignored: true

    function pad(h) {
        return (h < 10 ? "0" : "") + h;
    }

    function roleColor(role) {
        if (role === "golden")
            return Signal.alpha(ruler.sig.signal, 0.72);
        if (role === "day")
            return Signal.alpha(ruler.sig.ink, 0.38);
        return Signal.alpha(ruler.sig.cue, 0.5);
    }

    // Same classification the MediaDeck uses (inclusive window ends), so
    // the bands always match the footage mood on screen.
    function partAt(hour) {
        var part = Catalog.daypartForHour(hour, ruler.dayStart, ruler.dayEnd, ruler.goldenStart, ruler.goldenEnd);
        return part === "golden-hour" ? "golden" : part;
    }

    function bandColor(hour) {
        return roleColor(partAt(hour));
    }

    // Legend rows derived from the classified hours: contiguous ranges per
    // mood, end hour exclusive (a 17-20 inclusive window reads 17–21).
    function legendModel() {
        var labels = {
            "day": "DAY",
            "golden": "GOLDEN",
            "night": "NIGHT"
        };
        var ranges = {
            "day": [],
            "golden": [],
            "night": []
        };
        var start = 0;
        for (var h = 1; h <= 24; h++) {
            if (h === 24 || partAt(h) !== partAt(start)) {
                ranges[partAt(start)].push([start, h]);
                start = h;
            }
        }
        // A night range crossing midnight reads as one span (20–07).
        var night = ranges.night;
        if (night.length > 1 && night[0][0] === 0 && night[night.length - 1][1] === 24) {
            night[night.length - 1] = [night[night.length - 1][0], night[0][1]];
            night.shift();
        }
        var out = [];
        ["day", "golden", "night"].forEach(function (role) {
            ranges[role].forEach(function (r) {
                out.push({
                    "label": labels[role] + " " + pad(r[0]) + "–" + pad(r[1] % 24),
                    "role": role
                });
            });
        });
        return out;
    }

    // Segmented daypart bands: one cell per hour, 2 px gaps (VU style).
    Row {
        id: bands
        y: 0
        width: parent.width
        height: 6
        spacing: 0

        Repeater {
            model: 24
            Item {
                required property int index
                width: ruler.hourWidth
                height: bands.height
                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 2
                    color: ruler.bandColor(parent.index)
                    opacity: parent.index === Math.floor(ruler.position * 24) ? 1 : 0.7
                }
            }
        }
    }

    // Hairline baseline with hour ticks; long ticks every 6 h.
    Rectangle {
        id: axis
        y: bands.height + 6
        width: parent.width
        height: 1
        color: ruler.sig.ruleStrong
    }

    Repeater {
        model: 25
        Rectangle {
            required property int index
            x: Math.min(index * ruler.hourWidth, ruler.width - 1)
            y: axis.y
            width: 1
            height: index % 6 === 0 ? 8 : 4
            color: index % 6 === 0 ? ruler.sig.inkMuted : ruler.sig.ruleStrong
        }
    }

    Repeater {
        model: 5
        Text {
            required property int index
            x: Math.max(0, Math.min(index * 6 * ruler.hourWidth - width / 2, ruler.width - width))
            y: axis.y + 12
            text: (index * 6 < 10 ? "0" : "") + index * 6
            color: ruler.sig.inkMuted
            font.family: Signal.FONT_MONO
            font.pixelSize: Signal.TYPE.small * ruler.fontScale
            font.features: {
                "tnum": 1
            }
        }
    }

    // Legend: what each band means, in the scale's own colours.
    Row {
        id: legend
        y: axis.y + 12 + 22 * ruler.fontScale
        spacing: 20 * ruler.fontScale

        Repeater {
            model: ruler.legendModel()

            Row {
                required property var modelData
                spacing: 8 * ruler.fontScale

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10 * ruler.fontScale
                    height: 6
                    color: ruler.roleColor(parent.modelData.role)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    color: ruler.sig.inkMuted
                    font.family: Signal.FONT_MONO
                    font.pixelSize: Signal.TYPE.small * ruler.fontScale
                    font.letterSpacing: Signal.TYPE.small * ruler.fontScale * 0.08
                    font.features: {
                        "tnum": 1
                    }
                }
            }
        }
    }

    // Now cursor: a signal needle sweeping in from 00 on first show.
    Item {
        id: cursor
        x: (ruler.armed ? ruler.position : 0) * ruler.width - 1
        y: -5
        width: 2
        height: axis.y + 14

        Behavior on x {
            NumberAnimation {
                duration: Signal.duration("scan", ruler.reducedMotion) * 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Signal.CURVE.sweep
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ruler.sig.signal
        }

        Rectangle {
            // Cursor cap: a 6 px square head, instrument-needle style.
            x: -2
            y: 0
            width: 6
            height: 3
            color: ruler.sig.signal
        }
    }
}
