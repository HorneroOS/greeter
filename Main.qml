// Hornero greeter (Qt6) on Hornero Signal (RFC 0001, HorneroOS/docs).
//
// A broadcast control-room login: licensed Argentine footage on the
// MediaDeck, a telemetry clock framed with registration marks on the left,
// one sign-in console on the right, and two hairline rails (station ident
// and power on top, scene credit and daypart on the bottom). Colour, type,
// geometry and motion come from components/Signal.js only.
//
// Derived from aerial-sddm-theme (GPL-3.0, see UPSTREAM.md and NOTICE).
// No network, no shell, no absolute paths.

import QtQuick
import QtQuick.Effects
import QtQuick.VirtualKeyboard
import SddmComponents 2.0
import "components"
import "components/Signal.js" as Signal
import "components/MediaCatalog.js" as Catalog
import "media/catalog.js" as CatalogData

Rectangle {
    id: container

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property bool largeText: config.largeText == "true"
    property bool highContrast: config.highContrast == "true"
    property bool reducedMotion: config.reducedMotion == "true"
    property bool virtualKeyboardAvailable: config.virtualKeyboardAvailable == "true"
    property bool virtualKeyboardVisible: container.virtualKeyboardAvailable && Qt.inputMethod.visible
    property real accessibilityScale: largeText ? 1.5 : 1.0
    readonly property var sig: Signal.palette(highContrast)
    // Layout unit: 1.0 at 1080p, clamped so 720p and 4K both compose.
    readonly property real unit: Math.max(0.72, Math.min(2.0, Math.min(width / 1920, height / 1080)))
    // Text and controls never shrink below the RFC type scale (small = 11 px)
    // on small screens; only layout geometry follows `unit` down.
    readonly property real typeUnit: Math.max(1.0, unit)
    readonly property real margin: Math.round(72 * unit)
    property bool armed: false
    property string sceneId: ""
    property string loginError: ""
    readonly property string hostName: sddm.hostName !== "" ? sddm.hostName : "HorneroOS"

    color: sig.ground

    // Keyboard order: sign-in console first, then the console selectors,
    // then the top-rail controls. Hidden or unavailable controls are
    // skipped, so Tab never lands on an invisible item.
    function focusChain() {
        var chain = [username_input_box, password_input_box, login_button, session, language, keyboard_toggle, reboot_button, shutdown_button];
        return chain.filter(function (item) {
            return item.visible && item.enabled;
        });
    }

    function moveFocus(from, backwards) {
        var chain = container.focusChain();
        var i = chain.indexOf(from);
        var next = backwards ? (i <= 0 ? chain.length - 1 : i - 1) : (i < 0 || i >= chain.length - 1 ? 0 : i + 1);
        chain[next].forceActiveFocus();
    }

    // "-03" -> "UTC−03"; named zones (ART, CET) pass through unchanged.
    function zoneLabel(zone) {
        if (/^[+-]\d/.test(zone))
            return "UTC" + zone.replace("-", "\u2212");
        return zone;
    }

    function login() {
        container.loginError = "";
        sddm.login(username_input_box.text, password_input_box.text, session.index);
    }

    function focusCredentials() {
        if (username_input_box.text == "")
            username_input_box.forceActiveFocus();
        else
            password_input_box.forceActiveFocus();
    }

    function toggleVirtualKeyboard() {
        if (!container.virtualKeyboardAvailable)
            return;
        if (Qt.inputMethod.visible) {
            Qt.inputMethod.hide();
        } else {
            if (!username_input_box.activeFocus && !password_input_box.activeFocus)
                username_input_box.forceActiveFocus();
            Qt.inputMethod.show();
        }
    }

    TextConstants {
        id: textConstants
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
        }

        function onLoginFailed() {
            container.loginError = textConstants.loginFailed;
            password_input_box.text = "";
            password_input_box.forceActiveFocus();
        }
    }

    // ── Scene: still fallback, video deck, grade ─────────────────────────

    Image {
        id: image1
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }

    AnimatedImage {
        id: animatedGIF1
        anchors.fill: parent
        fillMode: AnimatedImage.PreserveAspectCrop
    }

    MediaDeck {
        id: deck

        anchors.fill: parent
        focus: true
        crossfadeDuration: parseInt(config.crossfadeDuration || "3000", 10)
        videoEnabled: config.videoEnabled != "false"
        testMode: config.testMode == "true"
        onBackgroundPressed: container.focusCredentials()
        // Typing before any field has focus lands in the right field: the
        // first keypress is never swallowed.
        Keys.onPressed: function (event) {
            container.focusCredentials();
            var target = username_input_box.activeFocus ? username_input_box : password_input_box;
            if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                target.text += event.text;
                event.accepted = true;
            }
        }
    }

    // Grade: a flat ground wash over footage and stills alike (no blur,
    // no glass) so the instruments stay legible over the busiest frame.
    Rectangle {
        id: grade
        anchors.fill: parent
        color: Signal.alpha(container.sig.ground, 0.16)
    }

    // Legibility scrims: a ground wash from the leading edge (clock) and a
    // lift from the bottom rail. Plain gradients in the ground role.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Signal.alpha(container.sig.ground, container.highContrast ? 0.92 : 0.82)
            }
            GradientStop {
                position: 0.42
                color: Signal.alpha(container.sig.ground, container.highContrast ? 0.75 : 0.48)
            }
            GradientStop {
                position: 0.7
                color: Signal.alpha(container.sig.ground, container.highContrast ? 0.75 : 0.30)
            }
            GradientStop {
                position: 1.0
                color: Signal.alpha(container.sig.ground, container.highContrast ? 0.88 : 0.66)
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.45
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Signal.alpha(container.sig.ground, 0)
            }
            GradientStop {
                position: 1.0
                color: Signal.alpha(container.sig.ground, 0.72)
            }
        }
    }

    // Registration grid: faint crosshairs every 120 px, like a technical
    // drawing sheet laid over the footage. Static; never animated.
    Item {
        id: registrationGrid
        anchors.fill: parent
        opacity: container.highContrast ? 0 : 0.5
        Accessible.ignored: true

        Repeater {
            model: Math.ceil(container.width / (120 * container.unit)) * Math.ceil(container.height / (120 * container.unit))
            Item {
                required property int index
                readonly property int cols: Math.ceil(container.width / (120 * container.unit))
                x: (index % cols) * 120 * container.unit + 60 * container.unit - 4
                y: Math.floor(index / cols) * 120 * container.unit + 60 * container.unit - 4
                width: 9
                height: 9
                Rectangle {
                    x: 4
                    width: 1
                    height: 9
                    color: Signal.alpha(container.sig.ink, 0.16)
                }
                Rectangle {
                    y: 4
                    width: 9
                    height: 1
                    color: Signal.alpha(container.sig.ink, 0.16)
                }
            }
        }
    }

    // ── Telemetry clock (instrument module) ──────────────────────────────
    // The clock reveals once with a `sweep` clip over `scan` 480 ms (Signal
    // Visual Language §11.2), plus 6 px settle travel. With reduced motion
    // it is simply there.

    Item {
        id: clock

        property date dateTime: new Date()
        readonly property real s: container.typeUnit * container.accessibilityScale

        x: container.margin + (container.armed ? 0 : -6)
        width: Math.min(Math.round(720 * container.unit), container.width * 0.5)
        height: clockColumn.height
        y: Math.round(container.height * 0.53 - height / 2)

        Behavior on x {
            NumberAnimation {
                duration: Signal.duration("settle", container.reducedMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Signal.CURVE.settle
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clock.dateTime = new Date()
        }

        // Scan-in: clip wipe from the leading edge.
        Item {
            id: clockReveal
            width: container.armed ? clock.width + 40 : 0
            height: clock.height + 40
            x: -20
            y: -20
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Signal.duration("scan", container.reducedMotion)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Signal.CURVE.sweep
                }
            }

            Column {
                id: clockColumn
                x: 20
                y: 20
                width: clock.width
                spacing: Math.round(10 * clock.s)

                // 01 · LOCAL TIME ─────────────────────────────────
                Item {
                    width: parent.width
                    height: clockEyebrow.height

                    Text {
                        id: clockEyebrow
                        text: "01 · LOCAL TIME"
                        color: container.sig.inkMuted
                        font.family: Signal.FONT_MONO
                        font.pixelSize: Signal.TYPE.smaller * clock.s
                        font.letterSpacing: Signal.TYPE.smaller * clock.s * 0.08
                    }

                    Rectangle {
                        anchors.left: clockEyebrow.right
                        anchors.leftMargin: Signal.SPACING.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: clockEyebrow.verticalCenter
                        height: 1
                        color: container.sig.rule
                    }
                }

                Text {
                    id: time
                    text: Qt.formatTime(clock.dateTime, config.timeFormat || "hh:mm")
                    color: container.sig.ink
                    font.family: Signal.FONT_DISPLAY
                    font.weight: Font.Light
                    font.pixelSize: Math.round(168 * container.unit) * container.accessibilityScale
                    font.letterSpacing: -2 * container.unit
                    font.features: {
                        "tnum": 1
                    }
                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Current time " + time.text
                }

                Text {
                    id: date
                    width: parent.width
                    text: Qt.formatDate(clock.dateTime, config.dateFormat || "dddd d MMMM yyyy").toUpperCase()
                    elide: Text.ElideRight
                    color: container.sig.ink
                    font.family: Signal.FONT_DISPLAY
                    font.weight: Font.Normal
                    font.pixelSize: Signal.TYPE.extraLarge * clock.s
                    font.letterSpacing: Signal.TYPE.extraLarge * clock.s * 0.06
                    font.features: {
                        "tnum": 1
                    }
                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Current date " + Qt.formatDate(clock.dateTime, Qt.DefaultLocaleLongDate)
                }

                Item {
                    width: 1
                    height: Math.round(6 * clock.s)
                }

                // Readout wells: seconds, zone, daypart (real values only).
                Row {
                    id: readouts
                    spacing: Signal.SPACING.smaller

                    ReadoutWell {
                        sig: container.sig
                        fontScale: clock.s
                        scanlines: !container.highContrast
                        eyebrow: "SEC"
                        value: Qt.formatTime(clock.dateTime, "ss")
                        valueColor: container.sig.signal
                        width: Math.max(implicitWidth, 76 * clock.s)
                    }

                    ReadoutWell {
                        sig: container.sig
                        fontScale: clock.s
                        scanlines: !container.highContrast
                        eyebrow: "ZONE"
                        value: container.zoneLabel(Qt.formatDateTime(clock.dateTime, "t"))
                    }

                    ReadoutWell {
                        sig: container.sig
                        fontScale: clock.s
                        scanlines: !container.highContrast
                        eyebrow: "DAYPART"
                        value: deck.daypart.toUpperCase().replace("-", " ")
                    }
                }

                Item {
                    width: 1
                    height: Math.round(8 * clock.s)
                }

                DayScale {
                    id: dayScale
                    width: parent.width
                    sig: container.sig
                    now: clock.dateTime
                    fontScale: clock.s
                    reducedMotion: container.reducedMotion
                    armed: container.armed
                    dayStart: parseInt(config.dayTimeStart || "7", 10)
                    dayEnd: parseInt(config.dayTimeEnd || "19", 10)
                    goldenStart: parseInt(config.goldenHourStart || "17", 10)
                    goldenEnd: parseInt(config.goldenHourEnd || "20", 10)
                }
            }
        }

        // Registration marks framing the readout (technical-drawing corners).
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property bool isRight: index % 2 === 1
                readonly property bool isBottom: index >= 2
                readonly property real pad: 20 * container.unit
                x: isRight ? clock.width + pad - 14 : -pad
                y: isBottom ? clock.height + pad - 14 : -pad
                width: 14
                height: 14
                opacity: container.armed ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Signal.fadeDuration("medium", container.reducedMotion)
                    }
                }
                Rectangle {
                    x: parent.isRight ? 13 : 0
                    width: 1
                    height: 14
                    color: container.sig.ruleStrong
                }
                Rectangle {
                    y: parent.isBottom ? 13 : 0
                    width: 14
                    height: 1
                    color: container.sig.ruleStrong
                }
            }
        }
    }

    // ── Sign-in console ──────────────────────────────────────────────────

    Item {
        id: login_container

        readonly property real s: container.typeUnit * container.accessibilityScale
        readonly property real restY: Math.max(topRail.height + 24, Math.round(container.height * 0.53 - height / 2))

        width: Math.round(Math.min(460 * container.typeUnit * (container.largeText ? 1.3 : 1), container.width - 2 * container.margin))
        height: consoleColumn.height + 2 * consolePad.pad
        x: container.width - container.margin - width
        y: container.virtualKeyboardVisible ? Math.max(topRail.height + 12, container.height - virtualKeyboard.height - height - 24) : restY + (container.armed ? 0 : 6)
        opacity: container.armed ? 1 : 0

        // Large surface: `sweep` clip wipe plus 6 px `enter` travel, no
        // settle (Signal Visual Language §11.2).
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
            anchors.fill: consoleFace
            offset.y: 4
            blur: 12
            radius: consoleFace.radius
            color: Signal.alpha(container.sig.shadow, 0.35)
        }

        Rectangle {
            id: consoleFace
            anchors.fill: parent
            color: container.sig.panel
            radius: Signal.RADIUS.small
            border.width: 1
            border.color: container.highContrast ? container.sig.ruleStrong : container.sig.rule
        }

        // Scan-in: the console reveals by a clip wipe from its leading edge.
        Rectangle {
            id: scanWipe
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            radius: Signal.RADIUS.small
            color: container.sig.panel
            width: container.armed ? 0 : parent.width
            visible: width > 0
            z: 20
            Behavior on width {
                NumberAnimation {
                    duration: Signal.duration("long", container.reducedMotion)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Signal.CURVE.sweep
                }
            }
        }

        // Registration tick: the focused console's leading top corner.
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

        Item {
            id: consolePad
            readonly property real pad: Math.round(28 * login_container.s)
            anchors.fill: parent
            anchors.margins: pad
        }

        Column {
            id: consoleColumn
            x: consolePad.pad
            y: consolePad.pad
            width: parent.width - 2 * consolePad.pad
            spacing: Math.round(14 * login_container.s)

            Item {
                width: parent.width
                height: consoleEyebrow.height

                Text {
                    id: consoleEyebrow
                    text: "02 · SIGN IN"
                    color: container.sig.inkMuted
                    font.family: Signal.FONT_MONO
                    font.pixelSize: Signal.TYPE.small * login_container.s
                    font.letterSpacing: Signal.TYPE.small * login_container.s * 0.08
                }

                DiagonalHatch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(56 * login_container.s)
                    height: Math.round(8 * login_container.s)
                    color: Signal.alpha(container.sig.signal, 0.85)
                }
            }

            Text {
                id: welcome
                width: parent.width
                text: textConstants.welcomeText.arg(container.hostName)
                elide: Text.ElideRight
                color: container.sig.ink
                font.family: Signal.FONT_DISPLAY
                font.weight: Font.Medium
                font.pixelSize: Signal.TYPE.extraLarge * login_container.s
            }

            Rectangle {
                width: parent.width
                height: 1
                color: container.sig.rule
            }

            SignalField {
                id: username_input_box
                width: parent.width
                height: implicitHeight
                z: users.open ? 10 : 0
                sig: container.sig
                fontScale: login_container.s
                reducedMotion: container.reducedMotion
                eyebrow: textConstants.userName
                glyph: "user"
                text: userModel.lastUser
                trailingGlyph: userModel.count > 1 ? "chevron-down" : ""
                trailingName: "Choose user"
                onTrailingClicked: users.show()
                onAccepted: container.login()
                Accessible.name: "Username"
                Accessible.description: "Enter your account name"
                Keys.onTabPressed: function (event) {
                    container.moveFocus(username_input_box, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(username_input_box, true);
                    event.accepted = true;
                }
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Down && userModel.count > 1) {
                        users.show();
                        event.accepted = true;
                    }
                }

                ChoiceList {
                    id: users
                    sig: container.sig
                    model: userModel
                    textRole: "name"
                    fontScale: login_container.s
                    reducedMotion: container.reducedMotion
                    trigger: username_input_box
                    label: "Users"
                    width: parent.width
                    y: parent.height + 4
                    onChosen: function (i) {
                        username_input_box.text = userChoices.itemAt(i) ? userChoices.itemAt(i).name : username_input_box.text;
                        password_input_box.forceActiveFocus();
                    }
                }

                Repeater {
                    id: userChoices
                    model: userModel
                    delegate: Item {
                        required property string name
                        visible: false
                    }
                }
            }

            SignalField {
                id: password_input_box
                width: parent.width
                height: implicitHeight
                sig: container.sig
                fontScale: login_container.s
                reducedMotion: container.reducedMotion
                eyebrow: textConstants.password
                glyph: "lock"
                password: true
                invalid: container.loginError !== ""
                onAccepted: container.login()
                onTextChanged: {
                    if (text !== "")
                        container.loginError = "";
                }
                Accessible.name: "Password"
                Accessible.description: "Enter your password"
                Keys.onTabPressed: function (event) {
                    container.moveFocus(password_input_box, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(password_input_box, true);
                    event.accepted = true;
                }
            }

            // Status line: login failure (alert) or Caps Lock (signal).
            Item {
                id: statusLine
                width: parent.width
                height: Math.round(18 * login_container.s)

                Row {
                    spacing: Signal.SPACING.smaller
                    visible: error_message.text !== ""
                    anchors.verticalCenter: parent.verticalCenter

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "alert-triangle"
                        size: 14 * login_container.s
                        color: container.sig.alert
                    }

                    Text {
                        id: error_message
                        anchors.verticalCenter: parent.verticalCenter
                        text: container.loginError !== "" ? container.loginError : (keyboard.capsLock ? textConstants.capslockWarning : "")
                        color: container.loginError !== "" ? container.sig.alert : container.sig.signal
                        font.family: Signal.FONT_MONO
                        font.pixelSize: Signal.TYPE.smaller * login_container.s
                        font.letterSpacing: Signal.TYPE.smaller * login_container.s * 0.04
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
                text: textConstants.login
                glyph: "arrow-right"
                visible: config.showLoginButton != "false"
                Accessible.name: "Log in"
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
                    sig: container.sig
                    fontScale: login_container.s
                    reducedMotion: container.reducedMotion
                    opensUp: true
                    eyebrow: textConstants.session
                    accessibleName: "Desktop session"
                    model: sessionModel
                    textRole: "name"
                    index: sessionModel.lastIndex
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
                    width: Math.round(132 * login_container.s)
                    height: implicitHeight
                    sig: container.sig
                    fontScale: login_container.s
                    reducedMotion: container.reducedMotion
                    opensUp: true
                    eyebrow: textConstants.layout
                    accessibleName: "Keyboard layout"
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

        readonly property real s: container.typeUnit * container.accessibilityScale

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(48 * s)
        color: Signal.alpha(container.sig.base, container.highContrast ? 1 : 0.9)
        visible: config.showTopBar != "false"

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

            BrandingMark {
                id: brandMark
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(22 * topRail.s)
                height: Math.round(22 * topRail.s)
                brandingEnabled: config.brandingEnabled != "false"
                source: config.brandingLogo || "components/resources/hornero-symbolic.svg"
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
                Accessible.name: "Computer " + (sddm.hostName || "")
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
                text: "Keyboard"
                checked: container.virtualKeyboardVisible
                accessibleName: "Toggle on-screen keyboard"
                accessibleDescription: checked ? "Hide on-screen keyboard" : "Show on-screen keyboard"
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
                visible: keyboard_toggle.visible && (reboot_button.visible || shutdown_button.visible)
                width: 1
                height: Math.round(16 * topRail.s)
                color: container.sig.rule
            }

            SignalButton {
                id: reboot_button
                height: implicitHeight
                sig: container.sig
                fontScale: topRail.s
                reducedMotion: container.reducedMotion
                visible: sddm.canReboot
                glyph: "refresh"
                text: textConstants.reboot
                accessibleName: "Restart computer"
                onClicked: sddm.reboot()
                Keys.onTabPressed: function (event) {
                    container.moveFocus(reboot_button, false);
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    container.moveFocus(reboot_button, true);
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: reboot_button.visible && shutdown_button.visible
                width: 1
                height: Math.round(16 * topRail.s)
                color: container.sig.rule
            }

            SignalButton {
                id: shutdown_button
                height: implicitHeight
                sig: container.sig
                fontScale: topRail.s
                reducedMotion: container.reducedMotion
                visible: sddm.canPowerOff
                glyph: "power"
                text: textConstants.shutdown
                accessibleName: "Shut down computer"
                onClicked: sddm.powerOff()
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

    // ── Bottom rail: scene credit and daypart ────────────────────────────

    Item {
        id: bottomRail

        readonly property real s: container.typeUnit * container.accessibilityScale
        readonly property var credit: CatalogData.CREDITS ? CatalogData.CREDITS[container.sceneId] : undefined

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
            color: Signal.alpha(container.sig.ink, 0.14)
        }

        Row {
            id: sceneRow
            anchors.left: parent.left
            anchors.leftMargin: container.margin
            anchors.right: brandBlock.left
            anchors.rightMargin: Signal.SPACING.large
            anchors.verticalCenter: parent.verticalCenter
            spacing: Signal.SPACING.normal
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "03 · SCENE"
                color: container.sig.inkMuted
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * bottomRail.s
                font.letterSpacing: Signal.TYPE.small * bottomRail.s * 0.08
            }

            // On-air chip: amber "LIVE" while footage plays (the one glowing
            // item on screen, never animated), outlined "STILL" otherwise.
            OnAirChip {
                anchors.verticalCenter: parent.verticalCenter
                sig: container.sig
                fontScale: bottomRail.s
                live: deck.hasVideo
                glow: !container.highContrast
                text: deck.hasVideo ? "LIVE" : "STILL"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: bottomRail.credit !== undefined
                text: bottomRail.credit ? bottomRail.credit.title : ""
                color: container.sig.ink
                font.family: Signal.FONT_SANS
                font.pixelSize: Signal.TYPE.normal * bottomRail.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: bottomRail.credit !== undefined
                text: bottomRail.credit ? (bottomRail.credit.place + "  ·  " + bottomRail.credit.creator + "  ·  " + bottomRail.credit.license) : ""
                color: container.sig.inkMuted
                font.family: Signal.FONT_MONO
                font.pixelSize: Signal.TYPE.small * bottomRail.s
            }
        }

        Row {
            id: brandBlock
            anchors.right: parent.right
            anchors.rightMargin: container.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Signal.SPACING.normal

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

    InputPanel {
        id: virtualKeyboard
        z: 100
        x: 0
        y: container.virtualKeyboardVisible ? container.height - height : container.height
        width: container.width
        visible: container.virtualKeyboardVisible
    }

    Connections {
        target: deck
        function onCurrentIdChanged() {
            if (deck.hasVideo && deck.currentId !== "")
                container.sceneId = deck.currentId;
        }
        function onHasVideoChanged() {
            if (!deck.hasVideo)
                container.sceneId = container.stillId;
        }
    }

    property string stillId: ""

    Component.onCompleted: {
        var hour = new Date().getHours();
        var part = Catalog.daypartForHour(hour, config.dayTimeStart, config.dayTimeEnd, config.goldenHourStart, config.goldenHourEnd);
        // Dedicated local Argentine stills cover golden hour and night when
        // no suitable video exists; the day still covers a missing pack.
        var stillImage = part === "golden-hour" ? (config.bgImgGoldenHour || config.bgImgDay) : (part === "night" ? config.bgImgNight : config.bgImgDay);
        if (stillImage !== null && stillImage !== undefined && stillImage !== "") {
            var fileType = stillImage.substring(stillImage.lastIndexOf(".") + 1).toLowerCase();
            if (fileType === "gif")
                animatedGIF1.source = stillImage;
            else
                image1.source = stillImage;
            var base = stillImage.substring(stillImage.lastIndexOf("/") + 1);
            container.stillId = base.substring(0, base.lastIndexOf("."));
            container.sceneId = container.stillId;
        }
        deck.daypart = part;
        // Local media catalog, imported synchronously from the generated
        // media/catalog.js module. XMLHttpRequest is deliberately NOT used:
        // Qt disables GET on local files by default, so an XHR-loaded
        // catalog silently never arrives and no video ever plays. A missing
        // or invalid catalog simply leaves the static image visible.
        var raw = CatalogData.CATALOG;
        if (Catalog.validateCatalog(raw).ok) {
            var resolve = function resolve(list) {
                return list.map(function (e) {
                    return {
                        "id": e.id,
                        "daypart": e.daypart,
                        "kind": e.kind,
                        "url": Qt.resolvedUrl(e.file)
                    };
                });
            };
            deck.catalog = {
                "version": raw.version,
                "dayparts": {
                    "day": resolve(raw.dayparts.day),
                    "golden-hour": resolve(raw.dayparts["golden-hour"] || []),
                    "night": resolve(raw.dayparts.night)
                }
            };
        }
        if (config.autofocusInput != "false")
            container.focusCredentials();
        else
            deck.focus = true;
        if (container.virtualKeyboardAvailable && config.virtualKeyboardEnabled == "true") {
            username_input_box.forceActiveFocus();
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
