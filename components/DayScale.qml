// DayScale — 24 h telemetry ruler under the clock.
//
// Shows the greeter's own media dayparts (theme.conf day / golden-hour /
// night windows) as segmented bands and the current time as a signal
// cursor, so the footage mood on screen is explained, not decorative.
import QtQuick
import "Signal.js" as Signal

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

    function bandColor(hour) {
        if (hour >= ruler.goldenStart && hour < ruler.goldenEnd)
            return roleColor("golden");
        if (hour >= ruler.dayStart && hour < ruler.dayEnd)
            return roleColor("day");
        return roleColor("night");
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
            model: [
                {
                    "label": "DAY " + ruler.pad(ruler.dayStart) + "–" + ruler.pad(ruler.goldenStart),
                    "role": "day"
                },
                {
                    "label": "GOLDEN " + ruler.pad(ruler.goldenStart) + "–" + ruler.pad(ruler.goldenEnd),
                    "role": "golden"
                },
                {
                    "label": "NIGHT " + ruler.pad(ruler.goldenEnd) + "–" + ruler.pad(ruler.dayStart),
                    "role": "night"
                }
            ]

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
