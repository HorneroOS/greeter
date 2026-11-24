// Hornero greetd greeter (Qt6) on Hornero Signal (RFC 0001).
//
// The same instrument panel as the SDDM theme in this repository — the
// centred clock, user accounts as channels, one sign-in module — wired
// to greetd instead of SDDM. Unlike SDDM's one-shot login(user, pass),
// greetd drives a PAM conversation: the daemon may ask several
// questions (visible, secret) and post notices (info, error). This UI
// therefore renders whichever prompt the backend reports, one at a
// time, and only starts the chosen session after the daemon says the
// conversation succeeded.
//
// Colour, type and copy come from Signal.js / Strings.js, embedded
// verbatim from ../components so both greeters share one source.

import QtQuick
import QtQuick.Window
import "Signal.js" as Signal
import "Strings.js" as Strings

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    width: 1920
    height: 1080
    color: sig.ground
    title: "HorneroOS"

    readonly property bool light: Signal.isLight("auto", Qt.styleHints.colorScheme)
    readonly property var sig: Signal.palette(false, light)
    readonly property string lang: Strings.pick("auto", Qt.locale().name)
    readonly property var loc: Qt.locale()
    readonly property real unit: Math.max(0.72, Math.min(2.0, Math.min(width / 1920, height / 1080)))
    readonly property real s: Math.max(1.0, unit)

    property date now: new Date()
    property int channel: backend.lastUserIndex
    property bool otherSelected: backend.users.length === 0
    property int sessionIndex: 0
    property string pendingPower: ""

    readonly property var currentUser: (otherSelected || channel >= backend.users.length) ? null : backend.users[channel]
    readonly property string currentUserName: otherSelected ? usernameField.text.trim() : (currentUser ? currentUser.name : "")
    readonly property string currentUserLabel: otherSelected ? usernameField.text.trim() : (currentUser ? (currentUser.realName !== "" ? currentUser.realName : currentUser.name) : "")
    readonly property bool busy: backend.state === "authenticating" || backend.state === "starting"
    readonly property bool prompting: backend.promptKind !== "none"
    readonly property bool noSessions: backend.sessions.length === 0

    function tr(key) { return Strings.t(lang, key) }

    function greeting() {
        var h = now.getHours()
        var part = h < 6 ? "night" : h < 12 ? "morning" : h < 19 ? "afternoon" : "evening"
        return tr("greeting." + part)
    }

    function statusText() {
        if (!backend.daemonConnected) return tr("daemonDown")
        if (noSessions) return tr("noSessions")
        if (backend.errorMessage !== "") {
            if (backend.failedAttempts > 1)
                return tr("loginFailedCount").arg(backend.failedAttempts)
            if (backend.failedAttempts === 1)
                return tr("loginFailed")
            return backend.errorMessage
        }
        if (backend.state === "starting") return tr("started")
        if (backend.infoMessage !== "") return backend.infoMessage
        if (Qt.inputMethod && Qt.inputMethod.inputItemTransform === null) return ""
        return ""
    }

    function primaryAction() {
        if (pendingPower !== "") return
        if (prompting) {
            var answer = promptField.visible ? promptField.text : ""
            promptField.text = ""
            backend.respond(answer)
            return
        }
        if (busy || noSessions) return
        if (currentUserName === "") {
            usernameField.forceActiveFocus()
            return
        }
        backend.begin(currentUserName, sessionIndex)
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: backend
        function onPromptChanged() {
            if (root.prompting && promptField.visible)
                promptField.forceActiveFocus()
        }
        function onMessagesChanged() {
            if (!root.busy && backend.errorMessage !== "")
                root.focusPromptStart()
        }
    }

    function focusPromptStart() {
        if (otherSelected && usernameField.text === "")
            usernameField.forceActiveFocus()
    }

    // ── Top rail: station ident + power ─────────────────────────────────
    Row {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Math.round(40 * unit)
        spacing: 12 * s

        Text {
            text: "HorneroOS"
            color: sig.ink
            font { family: "IBM Plex Sans Condensed"; pixelSize: 20 * s; weight: Font.Medium }
        }
        Text {
            text: backend.hostname
            color: sig.inkFaint
            anchors.baseline: parent.children[0].baseline
            font { family: "IBM Plex Mono"; pixelSize: 12 * s }
        }
        Item { width: 1; height: 1 } // spacer marker; real stretch below
    }

    Row {
        anchors { top: parent.top; right: parent.right }
        anchors.margins: Math.round(40 * unit)
        spacing: 8 * s

        Repeater {
            model: [
                { "kind": "suspend", "label": root.tr("suspend"), "can": power.canSuspend },
                { "kind": "restart", "label": root.tr("restart"), "can": power.canReboot },
                { "kind": "shutdown", "label": root.tr("shutdown"), "can": power.canPowerOff }
            ]
            delegate: Rectangle {
                visible: modelData.can
                width: label.implicitWidth + 24 * s
                height: 32 * s
                radius: 3
                color: "transparent"
                border { color: sig.rule; width: 1 }
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: sig.inkMuted
                    font { family: "IBM Plex Sans"; pixelSize: 12 * s }
                }
                MouseArea { anchors.fill: parent; onClicked: root.pendingPower = modelData.kind }
            }
        }
    }

    // ── Centre column: clock, greeting, sign-in module ──────────────────
    Column {
        anchors.centerIn: parent
        width: Math.round(440 * s)
        spacing: 14 * s

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: now.toLocaleTimeString(loc, "HH:mm")
            color: sig.ink
            font { family: "IBM Plex Sans Condensed"; pixelSize: 96 * s; weight: Font.Medium }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56 * s; height: 2
            color: sig.signal
            opacity: 0.8
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: now.toLocaleDateString(loc, "dddd d MMMM").toUpperCase()
            color: sig.inkFaint
            font { family: "IBM Plex Mono"; pixelSize: 12 * s; letterSpacing: 2 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: greeting()
            color: sig.inkMuted
            font { family: "IBM Plex Sans"; pixelSize: 15 * s; italic: true }
        }

        Item { width: 1; height: 18 * s }

        // Sign-in module.
        Rectangle {
            width: parent.width
            height: module.implicitHeight + 36 * s
            color: sig.panel
            radius: 6
            border { color: sig.rule; width: 1 }

            Column {
                id: module
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 18 * s
                spacing: 12 * s

                Text {
                    text: busy && currentUserLabel !== "" ? tr("authFor").arg(currentUserLabel) : tr("eyebrow.signIn")
                    color: sig.inkFaint
                    font { family: "IBM Plex Mono"; pixelSize: 11 * s; letterSpacing: 2 }
                }

                // User channels (hidden while a conversation runs).
                Flow {
                    visible: !busy && backend.users.length > 0
                    width: parent.width
                    spacing: 8 * s
                    Repeater {
                        model: backend.users
                        delegate: Rectangle {
                            readonly property bool tuned: !otherSelected && root.channel === index
                            width: chLabel.implicitWidth + 28 * s
                            height: 44 * s
                            radius: 4
                            color: tuned ? sig.signalWell : sig.raised
                            border { color: tuned ? sig.signal : sig.rule; width: 1 }
                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tr("channel") + " " + String(index + 1).padStart(2, "0")
                                    color: tuned ? sig.onSignalWell : sig.inkFaint
                                    font { family: "IBM Plex Mono"; pixelSize: 9 * s }
                                }
                                Text {
                                    id: chLabel
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.realName !== "" ? modelData.realName : modelData.name
                                    color: tuned ? sig.onSignalWell : sig.ink
                                    font { family: "IBM Plex Sans"; pixelSize: 13 * s }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { otherSelected = false; channel = index }
                            }
                        }
                    }
                    Rectangle {
                        width: otherLabel.implicitWidth + 28 * s
                        height: 44 * s
                        radius: 4
                        color: otherSelected ? sig.signalWell : sig.raised
                        border { color: otherSelected ? sig.signal : sig.rule; width: 1 }
                        Text {
                            id: otherLabel
                            anchors.centerIn: parent
                            text: tr("channel.other")
                            color: otherSelected ? sig.onSignalWell : sig.ink
                            font { family: "IBM Plex Sans"; pixelSize: 13 * s }
                        }
                        MouseArea { anchors.fill: parent; onClicked: otherSelected = true }
                    }
                }

                // Typed user name (manual channel).
                Rectangle {
                    visible: !busy && (otherSelected || backend.users.length === 0)
                    width: parent.width; height: 40 * s
                    color: sig.sunken; radius: 4
                    border { color: usernameField.activeFocus ? sig.focus : sig.rule; width: 1 }
                    TextInput {
                        id: usernameField
                        anchors { fill: parent; margins: 10 * s }
                        color: sig.ink
                        font { family: "IBM Plex Sans"; pixelSize: 14 * s }
                        clip: true
                        onAccepted: root.primaryAction()
                        Text {
                            visible: parent.text === ""
                            text: tr("user")
                            color: sig.inkFaint
                            font: parent.font
                        }
                    }
                }

                // The live PAM prompt, exactly as greetd phrases it.
                Column {
                    visible: prompting
                    width: parent.width
                    spacing: 8 * s
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: backend.promptLabel
                        color: backend.promptKind === "error" ? sig.alert : sig.inkMuted
                        font { family: "IBM Plex Sans"; pixelSize: 13 * s }
                    }
                    Rectangle {
                        visible: backend.promptKind === "visible" || backend.promptKind === "secret"
                        width: parent.width; height: 40 * s
                        color: sig.sunken; radius: 4
                        border { color: promptField.activeFocus ? sig.focus : sig.rule; width: 1 }
                        TextInput {
                            id: promptField
                            anchors { fill: parent; margins: 10 * s }
                            color: sig.ink
                            echoMode: backend.promptKind === "secret" ? TextInput.Password : TextInput.Normal
                            font { family: "IBM Plex Sans"; pixelSize: 14 * s }
                            clip: true
                            onAccepted: root.primaryAction()
                        }
                    }
                }

                // Status line: words first, colour second.
                Text {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: statusText()
                    color: (backend.errorMessage !== "" || noSessions || !backend.daemonConnected) ? sig.alert : sig.inkMuted
                    font { family: "IBM Plex Sans"; pixelSize: 13 * s }
                }

                // Session selector: cycles through the installed entries.
                Row {
                    visible: !busy && !noSessions
                    spacing: 8 * s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tr("session")
                        color: sig.inkFaint
                        font { family: "IBM Plex Mono"; pixelSize: 11 * s }
                    }
                    Rectangle {
                        width: sessionLabel.implicitWidth + 24 * s
                        height: 30 * s
                        radius: 4
                        color: sig.raised
                        border { color: sig.rule; width: 1 }
                        Text {
                            id: sessionLabel
                            anchors.centerIn: parent
                            text: backend.sessions[sessionIndex] ? backend.sessions[sessionIndex].name : ""
                            color: sig.ink
                            font { family: "IBM Plex Sans"; pixelSize: 12 * s }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: sessionIndex = (sessionIndex + 1) % backend.sessions.length
                        }
                    }
                }

                Row {
                    spacing: 8 * s
                    width: parent.width

                    Rectangle {
                        width: parent.width - (busy ? 108 * s : 0)
                        height: 42 * s
                        radius: 4
                        color: (noSessions || !backend.daemonConnected) ? sig.raised : sig.signal
                        Text {
                            anchors.centerIn: parent
                            text: prompting ? tr("continue") : (busy ? tr("signingIn") : tr("login"))
                            color: (noSessions || !backend.daemonConnected) ? sig.inkFaint : sig.onSignal
                            font { family: "IBM Plex Sans"; pixelSize: 14 * s; weight: Font.Medium }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.primaryAction() }
                    }
                    Rectangle {
                        visible: busy
                        width: 100 * s
                        height: 42 * s
                        radius: 4
                        color: "transparent"
                        border { color: sig.rule; width: 1 }
                        Text {
                            anchors.centerIn: parent
                            text: tr("cancel")
                            color: sig.inkMuted
                            font { family: "IBM Plex Sans"; pixelSize: 13 * s }
                        }
                        MouseArea { anchors.fill: parent; onClicked: backend.cancel() }
                    }
                }
            }
        }
    }

    // ── Bottom rail ─────────────────────────────────────────────────────
    Text {
        anchors { bottom: parent.bottom; right: parent.right }
        anchors.margins: Math.round(40 * unit)
        text: "HORNERO SIGNAL · GREETD"
        color: sig.inkFaint
        font { family: "IBM Plex Mono"; pixelSize: 10 * s; letterSpacing: 2 }
    }

    // ── Power confirmation ──────────────────────────────────────────────
    Rectangle {
        visible: pendingPower !== ""
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: pendingPower = "" }

        Rectangle {
            anchors.centerIn: parent
            width: 360 * s
            height: confirmCol.implicitHeight + 36 * s
            color: sig.panel
            radius: 6
            border { color: sig.ruleStrong; width: 1 }
            MouseArea { anchors.fill: parent } // swallow clicks inside the card

            Column {
                id: confirmCol
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 18 * s
                spacing: 16 * s
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: pendingPower === "" ? "" : tr("confirm." + pendingPower)
                    color: sig.ink
                    font { family: "IBM Plex Sans"; pixelSize: 15 * s }
                }
                Row {
                    spacing: 8 * s
                    anchors.right: parent.right
                    Rectangle {
                        width: 110 * s; height: 36 * s; radius: 4
                        color: "transparent"
                        border { color: sig.rule; width: 1 }
                        Text {
                            anchors.centerIn: parent
                            text: tr("cancel")
                            color: sig.ink
                            font { family: "IBM Plex Sans"; pixelSize: 13 * s }
                        }
                        MouseArea { anchors.fill: parent; onClicked: pendingPower = "" }
                    }
                    Rectangle {
                        width: 110 * s; height: 36 * s; radius: 4
                        color: sig.alert
                        Text {
                            anchors.centerIn: parent
                            text: pendingPower === "" ? "" : tr(pendingPower)
                            color: sig.onAlert
                            font { family: "IBM Plex Sans"; pixelSize: 13 * s; weight: Font.Medium }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (pendingPower === "suspend") power.suspend()
                                else if (pendingPower === "restart") power.reboot()
                                else if (pendingPower === "shutdown") power.powerOff()
                                pendingPower = ""
                            }
                        }
                    }
                }
            }
        }
    }

    // Escape leaves a power confirmation first, then the conversation.
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (pendingPower !== "") pendingPower = ""
            else if (busy) backend.cancel()
        }
    }

    Component.onCompleted: focusPromptStart()
}
