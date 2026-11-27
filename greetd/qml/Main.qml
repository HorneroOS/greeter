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
    property string pendingTypedText: ""
    property string localError: ""

    readonly property var currentUser: (otherSelected || channel >= backend.users.length) ? null : backend.users[channel]
    readonly property string currentUserName: otherSelected ? usernameField.text.trim() : (currentUser ? currentUser.name : "")
    readonly property string currentUserLabel: otherSelected ? usernameField.text.trim() : (currentUser ? (currentUser.realName !== "" ? currentUser.realName : currentUser.name) : "")
    readonly property var currentSession: (sessionIndex >= 0 && sessionIndex < backend.sessions.length) ? backend.sessions[sessionIndex] : null
    readonly property bool currentSessionExperimental: currentSession ? (/experimental/i.test(currentSession.name || "") || /experimental/i.test(currentSession.id || "") || /experimental/i.test(currentSession.comment || "")) : false
    readonly property bool busy: backend.state === "authenticating" || backend.state === "starting"
    readonly property bool prompting: backend.promptKind !== "none"
    readonly property bool noSessions: backend.sessions.length === 0
    readonly property bool statusIsAlert: !backend.daemonConnected || noSessions || backend.errorMessage !== "" || localError !== ""
    readonly property bool statusIsBusy: !statusIsAlert && backend.state === "starting"
    readonly property bool statusIsInfo: !statusIsAlert && !statusIsBusy && backend.infoMessage !== ""

    function tr(key) {
        return Strings.t(lang, key);
    }

    function greeting() {
        return tr("greeting." + Strings.daypart(now.getHours()));
    }

    function statusText() {
        if (!backend.daemonConnected)
            return tr("daemonDown");
        if (noSessions)
            return tr("noSessions");
        if (localError !== "")
            return localError;
        if (backend.errorMessage !== "") {
            // Only a genuine auth failure gets the friendly retry copy;
            // protocol/daemon errors must surface their own description
            // (masking them once hid "a session is already being
            // configured" behind the wrong-password text).
            if (backend.lastFailureWasAuth && backend.failedAttempts > 1)
                return tr("loginFailedCount").arg(backend.failedAttempts);
            if (backend.lastFailureWasAuth && backend.failedAttempts === 1)
                return tr("loginFailed");
            return backend.errorMessage;
        }
        if (backend.state === "starting")
            return tr("started");
        if (backend.infoMessage !== "")
            return backend.infoMessage;
        return "";
    }

    function primaryAction() {
        if (pendingPower !== "")
            return;
        if (prompting) {
            var answer = promptField.visible ? promptField.text : "";
            promptField.text = "";
            backend.respond(answer);
            return;
        }
        if (busy || noSessions)
            return;
        if (currentUserName === "") {
            localError = tr("noUser");
            usernameField.forceActiveFocus();
            return;
        }
        localError = "";
        backend.begin(currentUserName, sessionIndex);
    }

    function requestPower(kind) {
        pendingPower = kind;
        confirmCancel.forceActiveFocus();
    }

    function cancelPower() {
        pendingPower = "";
        focusPromptStart();
    }

    function runPower(kind) {
        if (kind === "suspend")
            power.suspend();
        else if (kind === "restart")
            power.reboot();
        else if (kind === "shutdown")
            power.powerOff();
        pendingPower = "";
    }

    function focusChain() {
        var items = [];
        for (var i = 0; i < channelRepeater.count; ++i) {
            var ch = channelRepeater.itemAt(i);
            if (ch && ch.visible && ch.enabled)
                items.push(ch);
        }
        if (otherChannel.visible && otherChannel.enabled)
            items.push(otherChannel);
        if (usernameBox.visible && usernameField.enabled)
            items.push(usernameField);
        if (promptBox.visible && promptField.enabled)
            items.push(promptField);
        if (sessionButton.visible && sessionButton.enabled)
            items.push(sessionButton);
        if (loginButton.visible && loginButton.enabled)
            items.push(loginButton);
        if (cancelButton.visible && cancelButton.enabled)
            items.push(cancelButton);
        for (var j = 0; j < powerRepeater.count; ++j) {
            var pb = powerRepeater.itemAt(j);
            if (pb && pb.visible && pb.enabled)
                items.push(pb);
        }
        return items;
    }

    function moveFocus(current, backwards) {
        if (pendingPower !== "") {
            if (current === confirmCancel)
                confirmAction.forceActiveFocus();
            else
                confirmCancel.forceActiveFocus();
            return;
        }
        var chain = focusChain();
        if (chain.length === 0)
            return;
        var idx = chain.indexOf(current);
        var next = idx < 0 ? 0 : (idx + (backwards ? -1 : 1) + chain.length) % chain.length;
        chain[next].forceActiveFocus();
    }

    function routeFirstKeystroke(text) {
        if (text === "" || text.charCodeAt(0) < 32 || pendingPower !== "")
            return false;
        if (prompting && promptField.visible) {
            promptField.text += text;
            promptField.forceActiveFocus();
            return true;
        }
        if (otherSelected) {
            usernameField.text += text;
            usernameField.forceActiveFocus();
            return true;
        }
        if (!busy && !noSessions && backend.daemonConnected && currentUserName !== "") {
            pendingTypedText += text;
            backend.begin(currentUserName, sessionIndex);
            return true;
        }
        return false;
    }

    function focusPromptStart() {
        if (pendingPower !== "") {
            confirmCancel.forceActiveFocus();
            return;
        }
        if (prompting && promptField.visible) {
            promptField.forceActiveFocus();
            return;
        }
        if (otherSelected && usernameField.text === "") {
            usernameField.forceActiveFocus();
            return;
        }
        if (!busy && !noSessions && backend.daemonConnected && currentUserName !== "") {
            loginButton.forceActiveFocus();
            return;
        }
        surface.forceActiveFocus();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: backend
        function onPromptChanged() {
            if (root.prompting && promptField.visible) {
                if (root.pendingTypedText !== "") {
                    promptField.text += root.pendingTypedText;
                    root.pendingTypedText = "";
                }
                promptField.forceActiveFocus();
            }
        }
        function onMessagesChanged() {
            if (!root.busy && backend.errorMessage !== "") {
                root.pendingTypedText = "";
                root.focusPromptStart();
            }
        }
    }

    Item {
        id: surface
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier) {
                if (root.routeFirstKeystroke(event.text))
                    event.accepted = true;
            }
        }

        // ── Top rail: station ident + power ─────────────────────────────────
        Row {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            anchors.margins: Math.round(40 * unit)
            spacing: 12 * s

            Text {
                text: "HorneroOS"
                color: sig.ink
                font {
                    family: Signal.FONT_DISPLAY
                    pixelSize: 20 * s
                    weight: Font.Medium
                }
            }
            Text {
                text: backend.hostname
                color: sig.inkFaint
                anchors.baseline: parent.children[0].baseline
                font {
                    family: Signal.FONT_MONO
                    pixelSize: 12 * s
                }
            }
            Item {
                width: 1
                height: 1
            } // spacer marker; real stretch below
        }

        Row {
            anchors {
                top: parent.top
                right: parent.right
            }
            anchors.margins: Math.round(40 * unit)
            spacing: 8 * s

            Repeater {
                id: powerRepeater
                model: [
                    {
                        "kind": "suspend",
                        "label": root.tr("suspend"),
                        "a11y": root.tr("a11y.suspend"),
                        "can": power.canSuspend
                    },
                    {
                        "kind": "restart",
                        "label": root.tr("restart"),
                        "a11y": root.tr("a11y.restart"),
                        "can": power.canReboot
                    },
                    {
                        "kind": "shutdown",
                        "label": root.tr("shutdown"),
                        "a11y": root.tr("a11y.shutdown"),
                        "can": power.canPowerOff
                    }
                ]
                delegate: Rectangle {
                    id: powerBtn
                    visible: modelData.can
                    width: label.implicitWidth + 24 * s
                    height: 32 * s
                    radius: 3
                    color: "transparent"
                    border {
                        color: activeFocus ? sig.focus : sig.rule
                        width: activeFocus ? 2 : 1
                    }
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.a11y
                    Accessible.onPressAction: root.requestPower(modelData.kind)
                    Keys.onTabPressed: function (event) {
                        root.moveFocus(powerBtn, false);
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function (event) {
                        root.moveFocus(powerBtn, true);
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: function (event) {
                        root.requestPower(modelData.kind);
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: function (event) {
                        root.requestPower(modelData.kind);
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function (event) {
                        root.requestPower(modelData.kind);
                        event.accepted = true;
                    }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.label
                        color: sig.inkMuted
                        font {
                            family: Signal.FONT_SANS
                            pixelSize: 12 * s
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.requestPower(modelData.kind)
                    }
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
                font {
                    family: Signal.FONT_DISPLAY
                    pixelSize: 96 * s
                    weight: Font.Medium
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56 * s
                height: 2
                color: sig.signal
                opacity: 0.8
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: now.toLocaleDateString(loc, "dddd d MMMM").toUpperCase()
                color: sig.inkFaint
                font {
                    family: Signal.FONT_MONO
                    pixelSize: 12 * s
                    letterSpacing: 2
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: greeting()
                color: sig.inkMuted
                font {
                    family: Signal.FONT_SANS
                    pixelSize: 15 * s
                    italic: true
                }
            }

            Item {
                width: 1
                height: 18 * s
            }

            // Sign-in module.
            Rectangle {
                width: parent.width
                height: module.implicitHeight + 36 * s
                color: sig.panel
                radius: 6
                border {
                    color: sig.rule
                    width: 1
                }

                Column {
                    id: module
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    anchors.margins: 18 * s
                    spacing: 12 * s

                    Text {
                        text: busy && currentUserLabel !== "" ? tr("authFor").arg(currentUserLabel) : tr("eyebrow.signIn")
                        color: sig.inkFaint
                        font {
                            family: Signal.FONT_MONO
                            pixelSize: 11 * s
                            letterSpacing: 2
                        }
                    }

                    // User channels (hidden while a conversation runs).
                    Flow {
                        visible: !busy && backend.users.length > 0
                        width: parent.width
                        spacing: 8 * s
                        Repeater {
                            id: channelRepeater
                            model: backend.users
                            delegate: Rectangle {
                                id: chBtn
                                readonly property bool tuned: !otherSelected && root.channel === index
                                width: chLabel.implicitWidth + 28 * s
                                height: 44 * s
                                radius: 4
                                color: tuned ? sig.signalWell : sig.raised
                                border {
                                    color: activeFocus ? sig.focus : (tuned ? sig.signal : sig.rule)
                                    width: activeFocus ? 2 : 1
                                }
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: chLabel.text
                                Accessible.onPressAction: {
                                    root.otherSelected = false;
                                    root.localError = "";
                                    root.channel = index;
                                }
                                Keys.onTabPressed: function (event) {
                                    root.moveFocus(chBtn, false);
                                    event.accepted = true;
                                }
                                Keys.onBacktabPressed: function (event) {
                                    root.moveFocus(chBtn, true);
                                    event.accepted = true;
                                }
                                Keys.onReturnPressed: function (event) {
                                    root.otherSelected = false;
                                    root.localError = "";
                                    root.channel = index;
                                    event.accepted = true;
                                }
                                Keys.onEnterPressed: function (event) {
                                    root.otherSelected = false;
                                    root.localError = "";
                                    root.channel = index;
                                    event.accepted = true;
                                }
                                Keys.onSpacePressed: function (event) {
                                    root.otherSelected = false;
                                    root.localError = "";
                                    root.channel = index;
                                    event.accepted = true;
                                }
                                Keys.onPressed: function (event) {
                                    if (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier) {
                                        if (root.routeFirstKeystroke(event.text))
                                            event.accepted = true;
                                    }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tr("channel") + " " + String(index + 1).padStart(2, "0")
                                        color: tuned ? sig.onSignalWell : sig.inkFaint
                                        font {
                                            family: Signal.FONT_MONO
                                            pixelSize: 9 * s
                                        }
                                    }
                                    Text {
                                        id: chLabel
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.realName !== "" ? modelData.realName : modelData.name
                                        color: tuned ? sig.onSignalWell : sig.ink
                                        font {
                                            family: Signal.FONT_SANS
                                            pixelSize: 13 * s
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.otherSelected = false;
                                        root.localError = "";
                                        root.channel = index;
                                    }
                                }
                            }
                        }
                        Rectangle {
                            id: otherChannel
                            width: otherLabel.implicitWidth + 28 * s
                            height: 44 * s
                            radius: 4
                            color: otherSelected ? sig.signalWell : sig.raised
                            border {
                                color: activeFocus ? sig.focus : (otherSelected ? sig.signal : sig.rule)
                                width: activeFocus ? 2 : 1
                            }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: tr("channel.other")
                            Accessible.onPressAction: {
                                root.otherSelected = true;
                                root.localError = "";
                                usernameField.forceActiveFocus();
                            }
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(otherChannel, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(otherChannel, true);
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function (event) {
                                root.otherSelected = true;
                                root.localError = "";
                                usernameField.forceActiveFocus();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function (event) {
                                root.otherSelected = true;
                                root.localError = "";
                                usernameField.forceActiveFocus();
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function (event) {
                                root.otherSelected = true;
                                root.localError = "";
                                usernameField.forceActiveFocus();
                                event.accepted = true;
                            }
                            Text {
                                id: otherLabel
                                anchors.centerIn: parent
                                text: tr("channel.other")
                                color: otherSelected ? sig.onSignalWell : sig.ink
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 13 * s
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.otherSelected = true;
                                    root.localError = "";
                                    usernameField.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Typed user name (manual channel).
                    Rectangle {
                        id: usernameBox
                        visible: !busy && (otherSelected || backend.users.length === 0)
                        width: parent.width
                        height: 40 * s
                        color: sig.sunken
                        radius: 4
                        border {
                            color: usernameField.activeFocus ? sig.focus : (localError !== "" ? sig.alert : sig.rule)
                            width: usernameField.activeFocus ? 2 : 1
                        }
                        TextInput {
                            id: usernameField
                            anchors {
                                fill: parent
                                margins: 10 * s
                            }
                            color: sig.ink
                            font {
                                family: Signal.FONT_SANS
                                pixelSize: 14 * s
                            }
                            clip: true
                            activeFocusOnTab: true
                            Accessible.role: Accessible.EditableText
                            Accessible.name: tr("a11y.username")
                            onTextChanged: {
                                if (text.trim() !== "" && root.localError === root.tr("noUser"))
                                    root.localError = "";
                            }
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(usernameField, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(usernameField, true);
                                event.accepted = true;
                            }
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
                            Accessible.role: backend.promptKind === "error" ? Accessible.AlertMessage : Accessible.StaticText
                            Accessible.name: text
                            font {
                                family: Signal.FONT_SANS
                                pixelSize: Math.max(13, Signal.TYPE.normal * s)
                            }
                        }
                        Rectangle {
                            id: promptBox
                            visible: backend.promptKind === "visible" || backend.promptKind === "secret"
                            width: parent.width
                            height: 40 * s
                            color: sig.sunken
                            radius: 4
                            border {
                                color: promptField.activeFocus ? sig.focus : sig.rule
                                width: promptField.activeFocus ? 2 : 1
                            }
                            TextInput {
                                id: promptField
                                anchors {
                                    fill: parent
                                    margins: 10 * s
                                }
                                color: sig.ink
                                echoMode: backend.promptKind === "secret" ? TextInput.Password : TextInput.Normal
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 14 * s
                                }
                                clip: true
                                activeFocusOnTab: true
                                Accessible.role: Accessible.EditableText
                                Accessible.name: backend.promptLabel !== "" ? backend.promptLabel : tr("a11y.password")
                                Accessible.passwordEdit: backend.promptKind === "secret"
                                Keys.onTabPressed: function (event) {
                                    root.moveFocus(promptField, false);
                                    event.accepted = true;
                                }
                                Keys.onBacktabPressed: function (event) {
                                    root.moveFocus(promptField, true);
                                    event.accepted = true;
                                }
                                onAccepted: root.primaryAction()
                            }
                        }
                    }

                    // Status line: glyph + words + colour (never colour alone),
                    // >= 13 px floor matching the SDDM greeter (greeter#45).
                    Row {
                        id: statusRow
                        visible: statusLabel.text !== ""
                        width: parent.width
                        spacing: Signal.SPACING.smaller

                        Glyph {
                            id: statusGlyph
                            anchors.verticalCenter: parent.verticalCenter
                            name: (statusIsBusy || statusIsInfo) ? "info-circle" : "alert-triangle"
                            size: 16 * s
                            color: statusLabel.color
                        }

                        Text {
                            id: statusLabel
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - statusGlyph.width - parent.spacing
                            wrapMode: Text.WordWrap
                            text: statusText()
                            color: statusIsAlert ? sig.alert : (statusIsBusy ? sig.phosphor : sig.cue)
                            Accessible.role: Accessible.AlertMessage
                            Accessible.name: text
                            font {
                                family: Signal.FONT_MONO
                                pixelSize: Math.max(13, Signal.TYPE.normal * s)
                                letterSpacing: 0.4
                            }
                        }
                    }

                    // Session selector: cycles through the installed entries.
                    Row {
                        visible: !busy && !noSessions
                        spacing: 8 * s
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tr("session")
                            color: sig.inkFaint
                            font {
                                family: Signal.FONT_MONO
                                pixelSize: 11 * s
                            }
                        }
                        Rectangle {
                            id: sessionButton
                            width: sessionLabel.implicitWidth + 24 * s
                            height: 30 * s
                            radius: 4
                            color: sig.raised
                            border {
                                color: activeFocus ? sig.focus : sig.rule
                                width: activeFocus ? 2 : 1
                            }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: tr("a11y.session") + ": " + sessionLabel.text + (currentSessionExperimental ? " (" + tr("experimental") + ")" : "")
                            Accessible.onPressAction: root.sessionIndex = (root.sessionIndex + 1) % backend.sessions.length
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(sessionButton, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(sessionButton, true);
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function (event) {
                                root.sessionIndex = (root.sessionIndex + 1) % backend.sessions.length;
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function (event) {
                                root.sessionIndex = (root.sessionIndex + 1) % backend.sessions.length;
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function (event) {
                                root.sessionIndex = (root.sessionIndex + 1) % backend.sessions.length;
                                event.accepted = true;
                            }
                            Text {
                                id: sessionLabel
                                anchors.centerIn: parent
                                text: currentSession ? currentSession.name : ""
                                color: sig.ink
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 12 * s
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.sessionIndex = (root.sessionIndex + 1) % backend.sessions.length
                            }
                        }
                        Rectangle {
                            visible: currentSessionExperimental
                            anchors.verticalCenter: parent.verticalCenter
                            width: expChipText.implicitWidth + 12 * s
                            height: 20 * s
                            radius: Signal.RADIUS.small
                            color: "transparent"
                            border {
                                color: sig.ruleStrong
                                width: 1
                            }
                            Text {
                                id: expChipText
                                anchors.centerIn: parent
                                text: tr("experimental")
                                color: sig.inkMuted
                                font {
                                    family: Signal.FONT_MONO
                                    pixelSize: Signal.TYPE.small * s
                                    letterSpacing: Signal.TYPE.small * s * 0.08
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 8 * s
                        width: parent.width

                        Rectangle {
                            id: loginButton
                            width: parent.width - (busy ? 108 * s : 0)
                            height: 42 * s
                            radius: 4
                            color: (noSessions || !backend.daemonConnected) ? sig.raised : sig.signal
                            border {
                                color: activeFocus ? sig.focus : "transparent"
                                width: activeFocus ? 2 : 0
                            }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: prompting ? tr("continue") : tr("a11y.login")
                            Accessible.onPressAction: root.primaryAction()
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(loginButton, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(loginButton, true);
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function (event) {
                                root.primaryAction();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function (event) {
                                root.primaryAction();
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function (event) {
                                root.primaryAction();
                                event.accepted = true;
                            }
                            Keys.onPressed: function (event) {
                                if (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier) {
                                    if (root.routeFirstKeystroke(event.text))
                                        event.accepted = true;
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: prompting ? tr("continue") : (busy ? tr("signingIn") : tr("login"))
                                color: (noSessions || !backend.daemonConnected) ? sig.inkFaint : sig.onSignal
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 14 * s
                                    weight: Font.Medium
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.primaryAction()
                            }
                        }
                        Rectangle {
                            id: cancelButton
                            visible: busy
                            width: 100 * s
                            height: 42 * s
                            radius: 4
                            color: "transparent"
                            border {
                                color: activeFocus ? sig.focus : sig.rule
                                width: activeFocus ? 2 : 1
                            }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: tr("a11y.cancel")
                            Accessible.onPressAction: backend.cancel()
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(cancelButton, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(cancelButton, true);
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function (event) {
                                backend.cancel();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function (event) {
                                backend.cancel();
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function (event) {
                                backend.cancel();
                                event.accepted = true;
                            }
                            Text {
                                anchors.centerIn: parent
                                text: tr("cancel")
                                color: sig.inkMuted
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 13 * s
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: backend.cancel()
                            }
                        }
                    }
                }
            }
        }

        // ── Bottom rail ─────────────────────────────────────────────────────
        Text {
            anchors {
                bottom: parent.bottom
                right: parent.right
            }
            anchors.margins: Math.round(40 * unit)
            text: "HORNERO SIGNAL · GREETD"
            color: sig.inkFaint
            font {
                family: Signal.FONT_MONO
                pixelSize: 10 * s
                letterSpacing: 2
            }
        }

        // ── Power confirmation ──────────────────────────────────────────────
        Rectangle {
            visible: pendingPower !== ""
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            Accessible.role: Accessible.Dialog
            Accessible.name: tr("a11y.confirm")
            MouseArea {
                anchors.fill: parent
                onClicked: root.cancelPower()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 360 * s
                height: confirmCol.implicitHeight + 36 * s
                color: sig.panel
                radius: 6
                border {
                    color: sig.ruleStrong
                    width: 1
                }
                MouseArea {
                    anchors.fill: parent
                } // swallow clicks inside the card

                Column {
                    id: confirmCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    anchors.margins: 18 * s
                    spacing: 16 * s
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: pendingPower === "" ? "" : tr("confirm." + pendingPower)
                        color: sig.ink
                        font {
                            family: Signal.FONT_SANS
                            pixelSize: 15 * s
                        }
                    }
                    Row {
                        spacing: 8 * s
                        anchors.right: parent.right
                        Rectangle {
                            id: confirmCancel
                            width: 110 * s
                            height: 36 * s
                            radius: 4
                            color: "transparent"
                            border {
                                color: activeFocus ? sig.focus : sig.rule
                                width: activeFocus ? 2 : 1
                            }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: tr("a11y.cancel")
                            Accessible.onPressAction: root.cancelPower()
                            Keys.onEscapePressed: root.cancelPower()
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(confirmCancel, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(confirmCancel, true);
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function (event) {
                                root.cancelPower();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function (event) {
                                root.cancelPower();
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function (event) {
                                root.cancelPower();
                                event.accepted = true;
                            }
                            Text {
                                anchors.centerIn: parent
                                text: tr("cancel")
                                color: sig.ink
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 13 * s
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.cancelPower()
                            }
                        }
                        Rectangle {
                            id: confirmAction
                            width: 110 * s
                            height: 36 * s
                            radius: 4
                            color: sig.alert
                            border {
                                color: activeFocus ? sig.focus : "transparent"
                                width: activeFocus ? 2 : 0
                            }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: pendingPower === "" ? "" : tr(pendingPower)
                            Accessible.onPressAction: root.runPower(root.pendingPower)
                            Keys.onEscapePressed: root.cancelPower()
                            Keys.onTabPressed: function (event) {
                                root.moveFocus(confirmAction, false);
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function (event) {
                                root.moveFocus(confirmAction, true);
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function (event) {
                                root.runPower(root.pendingPower);
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function (event) {
                                root.runPower(root.pendingPower);
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function (event) {
                                root.runPower(root.pendingPower);
                                event.accepted = true;
                            }
                            Text {
                                anchors.centerIn: parent
                                text: pendingPower === "" ? "" : tr(pendingPower)
                                color: sig.onAlert
                                font {
                                    family: Signal.FONT_SANS
                                    pixelSize: 13 * s
                                    weight: Font.Medium
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.runPower(root.pendingPower)
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
            if (pendingPower !== "")
                root.cancelPower();
            else if (busy)
                backend.cancel();
        }
    }

    Component.onCompleted: focusPromptStart()
}
