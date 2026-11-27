// Hornero greeter (Qt6) on Hornero Signal (RFC 0001, HorneroOS/docs).
//
// An original instrument-panel login in the same universe as the shell's
// lock screen and the reload-cover stand-by slate: the lock's centred clock
// (Plex Sans Condensed numerals, muted colon, one glowing signal hairline,
// mono date) and Javi's greeting, then one sign-in module where user
// accounts are channels, over a generative Pampa horizon drawn in code.
// The station ident and power sit on the top rail; the output, zone and
// brand on the bottom rail. Secondary outputs show a quiet plate.
//
// No bundled photos or videos, no network, no shell. An administrator may
// opt in to their own image or video (theme.conf backgroundImage). Colour,
// type, geometry and motion come from components/Signal.js; copy from
// components/Strings.js (English and Spanish).
//
// Started as a Qt6 port of aerial-sddm-theme (GPL-3.0, see UPSTREAM.md and
// NOTICE); the current composition is HorneroOS's own.

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import QtQuick.VirtualKeyboard
import "components"
import "components/Signal.js" as Signal
import "components/Strings.js" as Strings

Rectangle {
    id: container

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // ── Settings (theme.conf) ────────────────────────────────────────────
    property bool largeText: config.largeText == "true"
    property bool highContrast: config.highContrast == "true"
    property bool reducedMotion: config.reducedMotion == "true"
    property bool virtualKeyboardAvailable: config.virtualKeyboardAvailable == "true"
    property bool virtualKeyboardVisible: container.virtualKeyboardAvailable && Qt.inputMethod.visible
    property real accessibilityScale: largeText ? 1.5 : 1.0
    readonly property bool light: Signal.isLight(config.colorScheme || "auto", Qt.styleHints.colorScheme)
    readonly property var sig: Signal.palette(highContrast, light)
    readonly property string lang: Strings.pick(config.language || "auto", Qt.locale().name)
    // Dates follow the system locale unless theme.conf forces a language
    // the system locale does not speak.
    readonly property var loc: Strings.pick("auto", Qt.locale().name) === lang ? Qt.locale() : Qt.locale(lang === "es" ? "es_AR" : "en_US")
    readonly property bool cozy: config.voice != "plain"
    readonly property bool mascot: config.mascot != "false"
    readonly property bool confirmPower: config.confirmPower != "false"
    // SDDM sets primaryScreen per output view; older daemons do not, and
    // then every output is treated as the main one.
    readonly property bool isPrimary: typeof primaryScreen === "undefined" ? true : primaryScreen !== false

    // Model sources. The preview harness swaps these for fixtures in its
    // staged copy only (scripts/preview.sh --fixture).
    property var userSource: userModel
    property string lastUser: userModel.lastUser
    property var sessionSource: sessionModel
    property int sessionLastIndex: sessionModel.lastIndex

    // Layout unit: 1.0 at 1080p, clamped so 720p and 4K both compose.
    readonly property real unit: Math.max(0.72, Math.min(2.0, Math.min(width / 1920, height / 1080)))
    // Text and controls never shrink below the RFC type scale (small = 11 px)
    // on small screens; only layout geometry follows `unit` down.
    readonly property real typeUnit: Math.max(1.0, unit)
    readonly property real s: container.typeUnit * container.accessibilityScale
    readonly property real margin: Math.round(56 * unit)
    property bool armed: false
    property date now: new Date()
    readonly property string hostName: sddm.hostName !== "" ? sddm.hostName : "HorneroOS"

    // ── Sign-in state ────────────────────────────────────────────────────
    property string loginError: ""
    property int failures: 0
    property bool signingIn: false
    property string infoMessage: ""
    property string pendingPower: ""
    property var userRows: []
    property int channel: 0
    readonly property bool showChannels: config.showUserChannels != "false" && container.userRows.length > 0
    readonly property bool manualEntry: !container.showChannels || channels.otherSelected
    readonly property bool noSessions: sessionMirror.count === 0
    readonly property var status: {
        if (container.loginError !== "")
            return {
                "kind": "alert",
                "text": container.loginError
            };
        if (container.noSessions)
            return {
                "kind": "alert",
                "text": container.tr("noSessions")
            };
        if (container.signingIn)
            return {
                "kind": "busy",
                "text": container.tr("signingIn")
            };
        if (container.infoMessage !== "")
            return {
                "kind": "info",
                "text": container.infoMessage
            };
        if (keyboard.capsLock)
            return {
                "kind": "caps",
                "text": container.tr("capsLock")
            };
        return {
            "kind": "",
            "text": ""
        };
    }

    color: sig.ground

    function tr(key) {
        return Strings.t(container.lang, key);
    }

    // Keyboard order: channels (one stop), the typed user name when shown,
    // password, log in, the module selectors, then the top-rail controls.
    // Hidden or disabled controls are skipped, so Tab never lands on an
    // invisible item.
    function focusChain() {
        var chain = [channels, username_input_box, password_input_box, login_button, session, language, keyboard_toggle, suspend_button, reboot_button, shutdown_button];
        return chain.filter(function (item) {
            return item.visible && item.enabled;
        });
    }

    function moveFocus(from, backwards) {
        var chain = container.focusChain();
        if (chain.length === 0)
            return;
        var i = chain.indexOf(from);
        var next = backwards ? (i <= 0 ? chain.length - 1 : i - 1) : (i < 0 || i >= chain.length - 1 ? 0 : i + 1);
        chain[next].forceActiveFocus();
    }

    // "-03" -> "UTC−03"; named zones (ART, CET) pass through unchanged.
    function zoneLabel(zone) {
        if (/^[+-]\d/.test(zone))
            return "UTC" + zone.replace("-", "−");
        return zone;
    }

    function currentUserName() {
        if (container.manualEntry)
            return username_input_box.text.trim();
        var row = container.userRows[container.channel];
        return row ? row.name : "";
    }

    function currentUserLabel() {
        if (container.manualEntry)
            return username_input_box.text.trim();
        var row = container.userRows[container.channel];
        return row ? (row.realName !== "" ? row.realName : row.name) : "";
    }

    function login() {
        if (container.pendingPower !== "" || container.signingIn)
            return;
        if (container.noSessions)
            return;
        var user = container.currentUserName();
        if (user === "") {
            container.loginError = container.tr("noUser");
            username_input_box.forceActiveFocus();
            return;
        }
        container.loginError = "";
        container.infoMessage = "";
        container.signingIn = true;
        loginWatch.restart();
        sddm.login(user, password_input_box.text, container.sessionIndex(session.index));
    }

    function focusCredentials() {
        if (container.manualEntry && username_input_box.text === "")
            username_input_box.forceActiveFocus();
        else
            password_input_box.forceActiveFocus();
    }

    // Typed text that arrives before a field has focus lands in the right
    // field: the first keypress is never lost.
    function route(text) {
        container.focusCredentials();
        var target = username_input_box.activeFocus ? username_input_box : password_input_box;
        target.text += text;
    }

    function toggleVirtualKeyboard() {
        if (!container.virtualKeyboardAvailable)
            return;
        if (Qt.inputMethod.visible) {
            Qt.inputMethod.hide();
        } else {
            if (!username_input_box.activeFocus && !password_input_box.activeFocus)
                container.focusCredentials();
            Qt.inputMethod.show();
        }
    }

    // Power actions ask first (theme.conf confirmPower=false skips it).
    function requestPower(kind) {
        if (!container.confirmPower) {
            container.runPower(kind);
            return;
        }
        container.pendingPower = kind;
        confirm_cancel.forceActiveFocus();
    }

    function runPower(kind) {
        container.pendingPower = "";
        if (kind === "suspend")
            sddm.suspend();
        else if (kind === "restart")
            sddm.reboot();
        else if (kind === "shutdown")
            sddm.powerOff();
    }

    function cancelPower() {
        var kind = container.pendingPower;
        container.pendingPower = "";
        var back = kind === "suspend" ? suspend_button : (kind === "restart" ? reboot_button : shutdown_button);
        if (back.visible)
            back.forceActiveFocus();
        else
            container.focusCredentials();
    }

    // ── Users: mirrored into rows so channels and fixtures read alike ───
    function syncUsers() {
        var rows = [];
        for (var i = 0; i < userMirror.count; i++) {
            var it = userMirror.itemAt(i);
            if (it)
                rows.push({
                    "name": it.name,
                    "realName": it.realName,
                    "icon": it.icon
                });
        }
        container.userRows = rows;
        var last = -1;
        for (var j = 0; j < rows.length; j++) {
            if (rows[j].name === container.lastUser)
                last = j;
        }
        container.channel = last >= 0 ? last : 0;
    }

    Repeater {
        id: userMirror

        model: container.userSource
        delegate: Item {
            required property string name
            required property string realName
            required property string icon
            visible: false
            Component.onCompleted: Qt.callLater(container.syncUsers)
        }
    }

    // ── Sessions in presentation order ──────────────────────────────────
    // Stable sessions first (Hornero ones ahead of others), experimental
    // ones last. `source` maps back to the SDDM session index used for
    // login. The default is the last used session unless that one is
    // experimental, then the first stable one.
    ListModel {
        id: sessionChoices
    }

    property var sessionRows: []
    property int sessionDefault: 0

    function sessionIndex(i) {
        return (i >= 0 && i < sessionChoices.count) ? sessionChoices.get(i).source : container.sessionLastIndex;
    }

    function isExperimental(name) {
        return /experimental/i.test(name);
    }

    function rebuildSessions() {
        var rows = container.sessionRows.slice();
        rows.sort(function (a, b) {
            var ka = (a.experimental ? 2 : 0) + (/hornero/i.test(a.name) ? 0 : (/hyprland/i.test(a.name) ? 0.5 : 1));
            var kb = (b.experimental ? 2 : 0) + (/hornero/i.test(b.name) ? 0 : (/hyprland/i.test(b.name) ? 0.5 : 1));
            return ka !== kb ? ka - kb : a.source - b.source;
        });
        sessionChoices.clear();
        var last = -1;
        for (var i = 0; i < rows.length; i++) {
            sessionChoices.append(rows[i]);
            if (rows[i].source === container.sessionLastIndex)
                last = i;
        }
        container.sessionDefault = (last >= 0 && !rows[last].experimental) ? last : 0;
    }

    Repeater {
        id: sessionMirror

        model: container.sessionSource
        delegate: Item {
            required property int index
            required property string name
            visible: false
            Component.onCompleted: {
                var rows = container.sessionRows.slice();
                rows.push({
                    "name": name,
                    "source": index,
                    "experimental": container.isExperimental(name)
                });
                container.sessionRows = rows;
                Qt.callLater(container.rebuildSessions);
            }
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            container.signingIn = false;
            loginWatch.stop();
        }

        function onLoginFailed() {
            container.signingIn = false;
            loginWatch.stop();
            container.failures += 1;
            container.loginError = container.failures > 1 ? container.tr("loginFailedCount").arg(container.failures) : container.tr("loginFailed");
            password_input_box.text = "";
            password_input_box.forceActiveFocus();
        }

        function onInformationMessage(message) {
            container.infoMessage = message;
        }
    }

    // Honest timeout: a daemon that never answers is reported, not hidden.
    Timer {
        id: loginWatch

        interval: 12000
        onTriggered: {
            if (container.signingIn) {
                container.signingIn = false;
                container.loginError = container.tr("noResponse");
            }
        }
    }

    // One clock for the whole screen; the minute is all that is shown.
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: container.now = new Date()
    }

    // ── Background: generative horizon, or the administrator's own media ─

    readonly property string backdropPath: config.backgroundImage || ""
    readonly property bool backdropIsVideo: /\.(mp4|webm|mkv|mov|m4v|ogv)$/i.test(container.backdropPath)
    readonly property bool backdropShown: container.backdropPath !== "" && (container.backdropIsVideo ? (userVideo.status === Loader.Ready && userVideo.item && !userVideo.item.failed) : userImage.status === Image.Ready)

    function seedFor(text) {
        var h = 2166136261;
        for (var i = 0; i < text.length; i++) {
            h ^= text.charCodeAt(i);
            h = Math.imul(h, 16777619) >>> 0;
        }
        return h;
    }

    HorizonField {
        id: field

        anchors.fill: parent
        visible: !container.backdropShown && config.background != "plain"
        sig: container.sig
        highContrast: container.highContrast
        reducedMotion: container.reducedMotion
        ambient: config.backgroundMotion != "false" && container.isPrimary
        // A new sky each day, unique per machine; pinned by backgroundSeed.
        seed: config.backgroundSeed && config.backgroundSeed !== "" ? parseInt(config.backgroundSeed, 10) : container.seedFor(container.hostName + "/" + Qt.formatDate(new Date(), "yyyy-MM-dd"))
    }

    Image {
        id: userImage

        anchors.fill: parent
        visible: !container.backdropIsVideo && status === Image.Ready
        source: container.backdropPath !== "" && !container.backdropIsVideo ? Qt.resolvedUrl(container.backdropPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        Accessible.ignored: true
    }

    Loader {
        id: userVideo

        anchors.fill: parent
        active: container.backdropIsVideo && container.backdropPath !== ""
        source: active ? "components/UserVideo.qml" : ""
        onLoaded: {
            item.reducedMotion = container.reducedMotion;
            item.source = Qt.resolvedUrl(container.backdropPath);
        }
    }

    // Flat ground wash over user media only (no blur, no glass), so the
    // instruments stay legible over the busiest picture.
    Rectangle {
        anchors.fill: parent
        visible: container.backdropShown
        color: Signal.alpha(container.sig.ground, Math.max(0.3, Math.min(0.9, parseFloat(config.backgroundDim || "0.55"))))
    }

    // Background focus sink: clicks and early typing go to the fields.
    Item {
        id: keySink

        anchors.fill: parent
        focus: true
        Keys.onPressed: function (event) {
            if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                container.route(event.text);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: container.focusCredentials()
        }
    }

    // ── Clock block (the lock screen's clock, greeting and accent) ──────

    readonly property real railHeight: topRail.visible ? topRail.height : 0
    readonly property real stackGap: Math.round(28 * unit)
    readonly property real availableHeight: height - railHeight - bottomRail.height - 2 * Math.round(16 * unit)
    // Stacked (lock-like centre column) when it fits; otherwise the clock
    // moves to the leading side and the module to the trailing side.
    readonly property bool split: clockBlock.height + stackGap + login_container.height > availableHeight
    readonly property real stackTop: railHeight + Math.round(16 * unit) + Math.max(0, (availableHeight - clockBlock.height - stackGap - login_container.height) / 2)

    Item {
        id: clockBlock

        readonly property real cs: container.typeUnit * Math.min(container.accessibilityScale, 1.25)
        readonly property string timeText: container.now.toLocaleTimeString(container.loc, config.timeFormat || "hh:mm")
        readonly property int colon: timeText.indexOf(":")

        visible: container.isPrimary && !(container.virtualKeyboardVisible && !container.split)
        width: Math.max(clockColumn.implicitWidth, Math.round(420 * container.unit))
        height: clockColumn.implicitHeight
        x: container.split ? container.margin : Math.round((container.width - width) / 2)
        y: container.split ? Math.round(container.railHeight + (container.height - container.railHeight - bottomRail.height - height) / 2) : container.stackTop

        Column {
            id: clockColumn

            anchors.horizontalCenter: container.split ? undefined : parent.horizontalCenter
            spacing: Math.round(10 * clockBlock.cs)

            // Scan-in: the numerals reveal once by a clip wipe from the
            // leading edge (`sweep`, `scan` 480 ms); the box keeps its final
            // size so nothing reflows. With reduced motion it is simply
            // there.
            Item {
                id: clockBox

                anchors.horizontalCenter: container.split ? undefined : parent.horizontalCenter
                implicitWidth: clockRow.implicitWidth
                implicitHeight: clockRow.implicitHeight
                width: implicitWidth
                height: implicitHeight
                Accessible.role: Accessible.StaticText
                Accessible.name: container.tr("a11y.time").arg(clockBlock.timeText)

                Item {
                    width: container.armed ? clockBox.width : 0
                    height: clockBox.height
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: Signal.duration("scan", container.reducedMotion)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Signal.CURVE.sweep
                        }
                    }

                    Row {
                        id: clockRow

                        readonly property int clockPx: Math.round(136 * container.unit * Math.min(container.accessibilityScale, 1.25))

                        spacing: Math.round(4 * container.unit)

                        Text {
                            text: clockBlock.colon > 0 ? clockBlock.timeText.substring(0, clockBlock.colon) : clockBlock.timeText
                            color: container.sig.ink
                            font.family: Signal.FONT_DISPLAY
                            font.weight: Font.Medium
                            font.pixelSize: clockRow.clockPx
                            font.letterSpacing: -clockRow.clockPx * 0.015
                            font.features: {
                                "tnum": 1
                            }
                        }

                        Text {
                            visible: clockBlock.colon > 0
                            text: ":"
                            color: container.sig.inkMuted
                            font.family: Signal.FONT_DISPLAY
                            font.weight: Font.Medium
                            font.pixelSize: clockRow.clockPx
                        }

                        Text {
                            visible: clockBlock.colon > 0
                            text: clockBlock.timeText.substring(clockBlock.colon + 1)
                            color: container.sig.ink
                            font.family: Signal.FONT_DISPLAY
                            font.weight: Font.Medium
                            font.pixelSize: clockRow.clockPx
                            font.letterSpacing: -clockRow.clockPx * 0.015
                            font.features: {
                                "tnum": 1
                            }
                        }
                    }
                }
            }

            // The one accent: a short signal hairline, the only glowing item
            // on screen (static, 40 %, 4 px; off in High Contrast).
            Item {
                anchors.horizontalCenter: container.split ? undefined : parent.horizontalCenter
                width: Math.round(48 * container.unit)
                height: 2

                RectangularShadow {
                    anchors.fill: accent
                    visible: !container.highContrast && !container.light
                    blur: 4
                    spread: 0
                    color: Signal.alpha(container.sig.glow, 0.4)
                }

                Rectangle {
                    id: accent

                    anchors.fill: parent
                    color: container.sig.signal
                }
            }

            Text {
                anchors.horizontalCenter: container.split ? undefined : parent.horizontalCenter
                text: container.now.toLocaleDateString(container.loc, config.dateFormat || "dddd d MMMM yyyy").toUpperCase()
                color: container.sig.inkMuted
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.larger * clockBlock.cs
                font.letterSpacing: Signal.TYPE.larger * clockBlock.cs * 0.08
                font.features: {
                    "tnum": 1
                }
                Accessible.role: Accessible.StaticText
                Accessible.name: container.tr("a11y.date").arg(container.now.toLocaleDateString(container.loc, Locale.LongFormat))
            }

            // Javi's greeting, in the shell's voice for this hour.
            Row {
                anchors.horizontalCenter: container.split ? undefined : parent.horizontalCenter
                spacing: Signal.SPACING.smaller

                HorneroSprite {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: container.mascot
                    sig: container.sig
                    light: container.light
                    pixel: Math.max(2, Math.round(2 * clockBlock.cs))
                    reducedMotion: container.reducedMotion
                }

                Text {
                    id: greeting

                    anchors.verticalCenter: parent.verticalCenter
                    text: container.tr((container.cozy ? "greeting." : "greetingPlain.") + Strings.daypart(container.now.getHours()))
                    color: container.sig.inkMuted
                    font.family: Signal.FONT_SANS
                    font.pixelSize: Signal.TYPE.larger * clockBlock.cs
                    Accessible.role: Accessible.StaticText
                    Accessible.name: container.tr("greetingPlain." + Strings.daypart(container.now.getHours()))
                }
            }
        }
    }

    // ── Sign-in module ───────────────────────────────────────────────────

    Item {
        id: login_container

        readonly property real s: container.s
        readonly property real pad: Math.round(22 * login_container.s)

        visible: container.isPrimary
        width: Math.round(Math.min(520 * container.typeUnit * (container.largeText ? 1.3 : 1), container.width - 2 * container.margin))
        height: moduleColumn.height + 2 * pad
        x: container.split ? container.width - container.margin - width : Math.round((container.width - width) / 2)
        readonly property real restY: container.split ? Math.max(container.railHeight + 16, Math.round(container.railHeight + (container.height - container.railHeight - bottomRail.height - height) / 2)) : container.stackTop + clockBlock.height + container.stackGap
        y: container.virtualKeyboardVisible ? Math.max(container.railHeight + 12, container.height - virtualKeyboard.height - height - 16) : restY + (container.armed ? 0 : 6)
        opacity: container.armed ? 1 : 0

        // Large surface: 6 px `enter` travel plus a fade, no settle (Signal
        // Visual Language §11.2).
        Behavior on y {
            NumberAnimation {
                duration: Signal.duration("long", container.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Signal.CURVE.enter
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Signal.fadeDuration("medium", container.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Signal.CURVE.enter
            }
        }

        RectangularShadow {
            anchors.fill: moduleFace
            offset.y: 4
            blur: 12
            radius: moduleFace.radius
            visible: !container.light
            color: Signal.alpha(container.sig.shadow, 0.35)
        }

        Rectangle {
            id: moduleFace

            anchors.fill: parent
            color: container.sig.panel
            radius: Signal.RADIUS.small
            border.width: 1
            border.color: container.highContrast ? container.sig.ruleStrong : container.sig.rule
        }

        // Registration tick: the active module's leading top corner.
        Rectangle {
            x: 0
            y: -1
            width: 2
            height: 10
            color: container.sig.signal
        }
        Rectangle {
            x: 0
            y: -1
            width: 10
            height: 2
            color: container.sig.signal
        }

        Column {
            id: moduleColumn

            x: login_container.pad
            y: login_container.pad
            width: parent.width - 2 * login_container.pad
            spacing: Math.round(12 * login_container.s)

            Item {
                width: parent.width
                height: moduleEyebrow.height
                visible: !container.virtualKeyboardVisible

                Text {
                    id: moduleEyebrow

                    text: container.tr("eyebrow.signIn")
                    color: container.sig.inkMuted
                    font.family: Signal.FONT_MONO
                    font.pixelSize: Signal.TYPE.small * login_container.s
                    font.letterSpacing: Signal.TYPE.small * login_container.s * 0.08
                }

                Text {
                    anchors.right: hatch.left
                    anchors.rightMargin: Signal.SPACING.smaller
                    anchors.verticalCenter: moduleEyebrow.verticalCenter
                    visible: container.showChannels
                    text: container.tr("eyebrow.channels") + " " + channels.count
                    color: container.sig.inkFaint
                    font.family: Signal.FONT_MONO
                    font.pixelSize: Signal.TYPE.small * login_container.s
                    font.letterSpacing: Signal.TYPE.small * login_container.s * 0.08
                }

                DiagonalHatch {
                    id: hatch

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(44 * login_container.s)
                    height: Math.round(8 * login_container.s)
                    color: Signal.alpha(container.sig.signal, 0.85)
                }
            }

            Rectangle {
                visible: !container.virtualKeyboardVisible
                width: parent.width
                height: 1
                color: container.sig.rule
            }

            ChannelStrip {
                id: channels

                width: parent.width
                height: implicitHeight
                visible: container.showChannels
                sig: container.sig
                lang: container.lang
                users: container.userRows
                allowOther: config.allowOtherUser != "false"
                currentIndex: container.channel
                fontScale: login_container.s
                reducedMotion: container.reducedMotion
                onTuned: function (i) {
                    container.channel = i;
                    container.loginError = "";
                    password_input_box.text = "";
                }
                onHandOff: container.focusCredentials()
                onTyped: function (text) {
                    container.route(text);
                }
                Keys.onTabPressed: function (event) {
                    container.moveFocus(channels, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(channels, true);
                    event.accepted = true;
                }
            }

            SignalField {
                id: username_input_box

                width: parent.width
                height: implicitHeight
                visible: container.manualEntry
                sig: container.sig
                fontScale: login_container.s
                reducedMotion: container.reducedMotion
                eyebrow: container.tr("user")
                glyph: "user"
                text: container.showChannels ? "" : container.lastUser
                invalid: container.loginError === container.tr("noUser")
                onAccepted: container.focusCredentials()
                onTextChanged: {
                    if (container.loginError === container.tr("noUser"))
                        container.loginError = "";
                }
                accessibleName: container.tr("a11y.username")
                accessibleDescription: container.tr("a11y.usernameHelp")
                Keys.onTabPressed: function (event) {
                    container.moveFocus(username_input_box, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(username_input_box, true);
                    event.accepted = true;
                }
            }

            SignalField {
                id: password_input_box

                width: parent.width
                height: implicitHeight
                sig: container.sig
                fontScale: login_container.s
                reducedMotion: container.reducedMotion
                eyebrow: container.currentUserLabel() !== "" ? container.tr("passwordFor").arg(container.currentUserLabel()) : container.tr("password")
                glyph: "lock"
                password: true
                invalid: container.loginError !== "" && container.loginError !== container.tr("noUser")
                onAccepted: container.login()
                onTextChanged: {
                    if (text !== "" && container.loginError !== container.tr("noUser"))
                        container.loginError = "";
                }
                accessibleName: container.tr("a11y.password")
                accessibleDescription: container.tr("a11y.passwordHelp").arg(container.currentUserLabel())
                Keys.onTabPressed: function (event) {
                    container.moveFocus(password_input_box, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(password_input_box, true);
                    event.accepted = true;
                }
            }

            // Status line: errors, no sessions, signing in, daemon messages
            // and Caps Lock, each with a glyph and words (never colour
            // alone), announced as an alert.
            Item {
                id: statusLine

                width: parent.width
                height: Math.max(Math.round(24 * login_container.s), statusRow.implicitHeight)

                Row {
                    id: statusRow

                    width: parent.width
                    spacing: Signal.SPACING.smaller
                    visible: error_message.text !== ""
                    anchors.verticalCenter: parent.verticalCenter

                    Glyph {
                        id: statusGlyph

                        anchors.verticalCenter: parent.verticalCenter
                        name: container.status.kind === "info" || container.status.kind === "busy" ? "info-circle" : "alert-triangle"
                        size: 16 * login_container.s
                        color: error_message.color
                    }

                    Text {
                        id: error_message

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - statusGlyph.width - parent.spacing
                        wrapMode: Text.WordWrap
                        text: container.status.text
                        color: container.status.kind === "alert" ? container.sig.alert : (container.status.kind === "caps" ? container.sig.signal : (container.status.kind === "busy" ? container.sig.phosphor : container.sig.cue))
                        font.family: Signal.FONT_MONO
                        // Never below 13 px: the failure must stay readable at
                        // every scale (greeter#45).
                        font.pixelSize: Math.max(13, Signal.TYPE.normal * login_container.s)
                        font.letterSpacing: 0.4
                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: text
                    }
                }
            }

            SignalButton {
                id: login_button

                width: parent.width
                height: implicitHeight
                sig: container.sig
                fontScale: login_container.s
                reducedMotion: container.reducedMotion
                primary: true
                enabled: !container.noSessions && !container.signingIn
                text: container.signingIn ? container.tr("signingIn") : container.tr("login")
                glyph: "arrow-right"
                visible: config.showLoginButton != "false"
                accessibleName: container.tr("a11y.login")
                onClicked: container.login()
                Keys.onTabPressed: function (event) {
                    container.moveFocus(login_button, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(login_button, true);
                    event.accepted = true;
                }
            }

            Row {
                id: selectors

                width: parent.width
                spacing: Signal.SPACING.normal
                z: 5

                SignalSelect {
                    id: session

                    width: parent.width - (language.visible ? language.width + parent.spacing : 0)
                    height: implicitHeight
                    enabled: !container.noSessions
                    sig: container.sig
                    lang: container.lang
                    fontScale: login_container.s
                    reducedMotion: container.reducedMotion
                    opensUp: true
                    eyebrow: container.tr("session")
                    accessibleName: container.tr("a11y.session")
                    model: sessionChoices
                    textRole: "name"
                    index: container.sessionDefault
                    Keys.onTabPressed: function (event) {
                        container.moveFocus(session, false);
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function (event) {
                        container.moveFocus(session, true);
                        event.accepted = true;
                    }
                }

                SignalSelect {
                    id: language

                    width: Math.round(128 * login_container.s)
                    height: implicitHeight
                    sig: container.sig
                    lang: container.lang
                    fontScale: login_container.s
                    reducedMotion: container.reducedMotion
                    opensUp: true
                    eyebrow: container.tr("layout")
                    accessibleName: container.tr("a11y.layout")
                    model: keyboard.layouts
                    textRole: "shortName"
                    index: keyboard.currentLayout
                    visible: count > 0
                    onActivated: function (i) {
                        keyboard.currentLayout = i;
                    }
                    Keys.onTabPressed: function (event) {
                        container.moveFocus(language, false);
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function (event) {
                        container.moveFocus(language, true);
                        event.accepted = true;
                    }

                    Connections {
                        target: keyboard
                        function onCurrentLayoutChanged() {
                            language.index = keyboard.currentLayout;
                        }
                    }
                }
            }
        }
    }

    // ── Top rail: station ident and power ────────────────────────────────

    Rectangle {
        id: topRail

        readonly property real s: container.s

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(48 * s)
        color: Signal.alpha(container.sig.base, container.highContrast ? 1 : 0.86)
        visible: container.isPrimary && config.showTopBar != "false"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: container.sig.rule
        }

        Row {
            id: ident

            anchors.left: parent.left
            anchors.leftMargin: container.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Signal.SPACING.normal

            HorneroMark {
                anchors.verticalCenter: parent.verticalCenter
                visible: !brandMark.visible
                size: Math.round(20 * topRail.s)
                color: container.sig.signal
            }

            BrandingMark {
                id: brandMark

                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(22 * topRail.s)
                height: Math.round(22 * topRail.s)
                brandingEnabled: config.brandingEnabled != "false" && (config.brandingLogo || "") !== ""
                source: config.brandingLogo || ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "HorneroOS"
                color: container.sig.ink
                font.family: Signal.FONT_SANS
                font.weight: Font.DemiBold
                font.pixelSize: Signal.TYPE.larger * topRail.s
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: sddm.hostName !== ""
                width: 1
                height: Math.round(16 * topRail.s)
                color: container.sig.ruleStrong
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: sddm.hostName !== ""
                text: sddm.hostName.toUpperCase()
                color: container.sig.inkMuted
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.smaller * topRail.s
                font.letterSpacing: Signal.TYPE.smaller * topRail.s * 0.08
                Accessible.role: Accessible.StaticText
                Accessible.name: container.tr("a11y.computer").arg(sddm.hostName || "")
            }
        }

        Row {
            id: power

            anchors.right: parent.right
            anchors.rightMargin: container.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Signal.SPACING.small

            SignalButton {
                id: keyboard_toggle

                height: implicitHeight
                sig: container.sig
                fontScale: topRail.s
                reducedMotion: container.reducedMotion
                visible: container.virtualKeyboardAvailable
                glyph: "keyboard"
                text: container.tr("keyboard")
                checked: container.virtualKeyboardVisible
                accessibleName: container.tr("a11y.keyboard")
                accessibleDescription: checked ? container.tr("a11y.keyboardHide") : container.tr("a11y.keyboardShow")
                Accessible.checkable: true
                Accessible.checked: checked
                onClicked: container.toggleVirtualKeyboard()
                Keys.onTabPressed: function (event) {
                    container.moveFocus(keyboard_toggle, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(keyboard_toggle, true);
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: keyboard_toggle.visible && (suspend_button.visible || reboot_button.visible || shutdown_button.visible)
                width: 1
                height: Math.round(16 * topRail.s)
                color: container.sig.rule
            }

            SignalButton {
                id: suspend_button

                height: implicitHeight
                sig: container.sig
                fontScale: topRail.s
                reducedMotion: container.reducedMotion
                visible: sddm.canSuspend
                glyph: "moon"
                text: container.tr("suspend")
                accessibleName: container.tr("a11y.suspend")
                onClicked: container.requestPower("suspend")
                Keys.onTabPressed: function (event) {
                    container.moveFocus(suspend_button, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(suspend_button, true);
                    event.accepted = true;
                }
            }

            SignalButton {
                id: reboot_button

                height: implicitHeight
                sig: container.sig
                fontScale: topRail.s
                reducedMotion: container.reducedMotion
                visible: sddm.canReboot
                glyph: "refresh"
                text: container.tr("restart")
                accessibleName: container.tr("a11y.restart")
                onClicked: container.requestPower("restart")
                Keys.onTabPressed: function (event) {
                    container.moveFocus(reboot_button, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(reboot_button, true);
                    event.accepted = true;
                }
            }

            SignalButton {
                id: shutdown_button

                height: implicitHeight
                sig: container.sig
                fontScale: topRail.s
                reducedMotion: container.reducedMotion
                visible: sddm.canPowerOff
                glyph: "power"
                text: container.tr("shutdown")
                accessibleName: container.tr("a11y.shutdown")
                onClicked: container.requestPower("shutdown")
                Keys.onTabPressed: function (event) {
                    container.moveFocus(shutdown_button, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(shutdown_button, true);
                    event.accepted = true;
                }
            }
        }
    }

    // ── Bottom rail: output, zone, brand ─────────────────────────────────

    Item {
        id: bottomRail

        readonly property real s: container.s

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(40 * s)
        visible: !container.virtualKeyboardVisible

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            visible: container.isPrimary
            color: Signal.alpha(container.sig.ink, 0.14)
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: container.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Signal.SPACING.large

            Text {
                visible: Screen.name !== ""
                text: container.tr("out") + " · " + Screen.name.toUpperCase()
                color: container.sig.inkFaint
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * bottomRail.s
                font.letterSpacing: Signal.TYPE.small * bottomRail.s * 0.12
            }

            Text {
                visible: container.isPrimary
                text: container.tr("zone") + " · " + container.zoneLabel(Qt.formatDateTime(container.now, "t"))
                color: container.sig.inkFaint
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * bottomRail.s
                font.letterSpacing: Signal.TYPE.small * bottomRail.s * 0.12
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: container.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Signal.SPACING.normal
            visible: container.isPrimary

            DiagonalHatch {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(40 * bottomRail.s)
                height: Math.round(10 * bottomRail.s)
                color: Signal.alpha(container.sig.ink, 0.45)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "HORNERO SIGNAL"
                color: container.sig.inkMuted
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * bottomRail.s
                font.letterSpacing: Signal.TYPE.small * bottomRail.s * 0.08
            }
        }
    }

    // ── Secondary outputs: a quiet plate ─────────────────────────────────

    Column {
        anchors.centerIn: parent
        visible: !container.isPrimary
        spacing: Math.round(14 * container.unit)

        HorneroMark {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.round(40 * container.typeUnit)
            color: container.sig.signal
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clockBlock.timeText
            color: container.sig.ink
            font.family: Signal.FONT_DISPLAY
            font.weight: Font.Medium
            font.pixelSize: Math.round(64 * container.unit * Math.min(container.accessibilityScale, 1.25))
            font.features: {
                "tnum": 1
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(160 * container.unit)
            height: 1
            color: container.sig.rule
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: container.tr("secondary")
            color: container.sig.inkMuted
            font.family: Signal.FONT_MONO
            font.pixelSize: Signal.TYPE.smaller * container.s
            font.letterSpacing: 3
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }

    // ── Power confirmation (modal) ───────────────────────────────────────

    Rectangle {
        id: powerScrim

        anchors.fill: parent
        z: 60
        visible: container.pendingPower !== ""
        color: Signal.alpha(container.sig.scrim, container.light ? 0.35 : 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: container.cancelPower()
        }
    }

    Item {
        id: confirmPanel

        readonly property real s: container.s
        readonly property real pad: Math.round(20 * s)

        z: 61
        visible: container.pendingPower !== ""
        width: Math.round(Math.min(420 * s, container.width - 2 * container.margin))
        height: confirmColumn.height + 2 * pad
        anchors.right: parent.right
        anchors.rightMargin: container.margin
        y: container.railHeight + Math.round(12 * container.unit)

        Accessible.role: Accessible.Dialog
        Accessible.name: container.tr("a11y.confirm")

        Keys.onEscapePressed: container.cancelPower()

        Rectangle {
            anchors.fill: parent
            color: container.sig.panel
            radius: Signal.RADIUS.small
            border.width: 1
            border.color: container.sig.ruleStrong
        }

        // Registration tick.
        Rectangle {
            x: 0
            y: -1
            width: 10
            height: 2
            color: container.sig.signal
        }

        Column {
            id: confirmColumn

            x: confirmPanel.pad
            y: confirmPanel.pad
            width: parent.width - 2 * confirmPanel.pad
            spacing: Math.round(12 * confirmPanel.s)

            Text {
                text: "02 · " + container.tr("eyebrow.power")
                color: container.sig.inkMuted
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * confirmPanel.s
                font.letterSpacing: Signal.TYPE.small * confirmPanel.s * 0.08
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: container.pendingPower !== "" ? container.tr("confirm." + container.pendingPower) : ""
                color: container.sig.ink
                font.family: Signal.FONT_DISPLAY
                font.weight: Font.Medium
                font.pixelSize: Signal.TYPE.large * confirmPanel.s
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            Row {
                anchors.right: parent.right
                spacing: Signal.SPACING.normal

                SignalButton {
                    id: confirm_cancel

                    height: Math.round(40 * confirmPanel.s)
                    sig: container.sig
                    fontScale: confirmPanel.s
                    reducedMotion: container.reducedMotion
                    text: container.tr("cancel")
                    accessibleName: container.tr("a11y.cancel")
                    onClicked: container.cancelPower()
                    Keys.onTabPressed: function (event) {
                        confirm_ok.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function (event) {
                        confirm_ok.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: container.cancelPower()
                }

                SignalButton {
                    id: confirm_ok

                    height: Math.round(40 * confirmPanel.s)
                    width: implicitWidth
                    sig: container.sig
                    fontScale: confirmPanel.s
                    reducedMotion: container.reducedMotion
                    primary: true
                    glyph: container.pendingPower === "suspend" ? "moon" : (container.pendingPower === "restart" ? "refresh" : "power")
                    text: container.pendingPower !== "" ? container.tr(container.pendingPower) : ""
                    accessibleName: text
                    onClicked: container.runPower(container.pendingPower)
                    Keys.onTabPressed: function (event) {
                        confirm_cancel.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function (event) {
                        confirm_cancel.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: container.cancelPower()
                }
            }
        }
    }

    InputPanel {
        id: virtualKeyboard

        z: 100
        x: 0
        y: container.virtualKeyboardVisible ? container.height - height : container.height
        width: container.width
        visible: container.virtualKeyboardVisible
    }

    Component.onCompleted: {
        if (!container.isPrimary)
            return;
        if (config.autofocusInput != "false")
            Qt.callLater(function () {
                if (container.showChannels && !container.manualEntry)
                    password_input_box.forceActiveFocus();
                else
                    container.focusCredentials();
            });
        if (container.virtualKeyboardAvailable && config.virtualKeyboardEnabled == "true") {
            container.focusCredentials();
            Qt.inputMethod.show();
        }
        armTimer.start();
    }

    // Arm the scan-in one frame after load so the reveal animates.
    Timer {
        id: armTimer

        interval: 60
        onTriggered: container.armed = true
    }
}
