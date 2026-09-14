// Hornero cinematic greeter (Qt6).
// Visual identity: warm charcoal surfaces, earth browns, terracotta and
// burnt-orange accents, cream type. The background video hero plays under a
// warm grade (tint wash, vertical gradient, side vignette) with a large
// light-weight clock, date, signature location rule and a borderless
// hairline login surface (no opaque card).
// All layout is relative to the screen size so 720p, 1080p, 1440p and HiDPI
// scale from the same file. No network, no shell, no absolute paths.

import QtQuick
import SddmComponents 2.0
import "components"
import "components/MediaCatalog.js" as Catalog
import "media/catalog.js" as CatalogData

Rectangle {
    id: container

    property int sessionIndex: session.index
    // Responsive scale: 1.0 on a 1280x720 canvas, clamped so small
    // screens stay legible and very large screens stay composed.
    property real uiScale: Math.max(0.7, Math.min(Math.min(width / 1280, height / 720), 1.8))
    // Hornero palette (theme.conf may override each of these).
    property color cream: config.creamColor || "#F4EAD8"
    property color muted: config.mutedColor || "#D8C3A5"
    property color accent: config.accentColor || "#D1541E"
    property color terra: config.terracottaColor || "#C2703D"
    property color surface: config.surfaceColor || "#B8241C15"
    property color surfaceBorder: config.surfaceBorderColor || "#66C2703D"
    // Hairline rules for the borderless login fields.
    property color hairline: "#59C2703D"
    property color hairlineFocus: config.terracottaColor || "#C2703D"
    // Display font family (Qt6 FontLoader.name is read-only, and the
    // configured value is a family name, so bind it directly).
    property string displayFont: config.displayFont || ""

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    Component.onCompleted: {
        deck.focus = true;
        // Static fallback image (local file only), layered under the deck.
        var hour = new Date().getHours();
        var part = Catalog.daypartForHour(hour, config.dayTimeStart, config.dayTimeEnd, config.goldenHourStart, config.goldenHourEnd);
        // Golden-hour is a mood of the video deck; stills stay day/night.
        var isDaytime = part !== "night";
        var stillImage = isDaytime ? config.bgImgDay : config.bgImgNight;
        if (stillImage !== null && stillImage !== undefined && stillImage !== "") {
            var fileType = stillImage.substring(stillImage.lastIndexOf(".") + 1).toLowerCase();
            if (fileType === "gif")
                animatedGIF1.source = stillImage;
            else
                image1.source = stillImage;
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
        if (config.showLoginButton == "false")
            login_button.visible = false;

        clear_passwd_button.visible = false;
        if (config.autofocusInput == "true")
            loginRevealTimer.start();
    }

    // Inherited from SDDMComponents
    TextConstants {
        id: textConstants
    }

    // Set SDDM actions
    Connections {
        function onLoginSucceeded() {
        }

        function onLoginFailed() {
            error_message.color = config.errorMsgFontColor;
            error_message.text = textConstants.loginFailed;
        }

        target: sddm
    }

    // Background Fill
    Rectangle {
        anchors.fill: parent
        color: "#14100C"
    }

    // Set Background Image
    Image {
        id: image1

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
    }

    // Set Animated GIF Background Image
    AnimatedImage {
        id: animatedGIF1

        anchors.fill: parent
        fillMode: AnimatedImage.PreserveAspectCrop
    }

    // Background video deck (Qt6): dual MediaPlayer/VideoOutput pairs with
    // crossfade, sequenced from the local media catalog. When no local clip
    // is playable the deck stays transparent and the static fallback image
    // underneath remains visible.
    MediaDeck {
        id: deck

        anchors.fill: parent
        focus: true
        crossfadeDuration: parseInt(config.crossfadeDuration || "3000", 10)
        videoEnabled: config.videoEnabled != "false"
        testMode: config.testMode == "true"
        onBackgroundPressed: {
            fader.state = fader.state == "off" ? "on" : "off";
            if (config.autofocusInput == "true") {
                if (username_input_box.text == "")
                    username_input_box.focus = true;
                else
                    password_input_box.focus = true;
            }
        }
        Keys.onPressed: {
            fader.state = "on";
            if (username_input_box.text == "")
                username_input_box.focus = true;
            else
                password_input_box.focus = true;
        }
    }

    WallpaperFader {
        id: fader

        visible: true
        anchors.fill: parent
        state: "off"
        source: deck
        mainStack: hero
        footer: actionBar
    }

    // Hornero cinematic grade over the video hero: warm tint wash,
    // vertical gradient (legibility top and bottom) and side vignette.
    // Plain items only, so background clicks still reach the deck.
    Rectangle {
        anchors.fill: parent
        color: "#2A1408"
        opacity: 0.22
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#99140D08"
            }

            GradientStop {
                position: 0.32
                color: "#00140D08"
            }

            GradientStop {
                position: 0.58
                color: "#55140D08"
            }

            GradientStop {
                position: 1
                color: "#E6140D08"
            }
        }
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "#7A140D08"
            }

            GradientStop {
                position: 0.2
                color: "#00140D08"
            }

            GradientStop {
                position: 0.8
                color: "#00140D08"
            }

            GradientStop {
                position: 1
                color: "#7A140D08"
            }
        }
    }

    // Gentle auto-reveal so the login surface appears on its own shortly
    // after boot, while a key press still reveals it instantly.
    Timer {
        id: loginRevealTimer

        interval: 1200
        running: false
        repeat: false
        onTriggered: {
            fader.state = "on";
            if (username_input_box.text == "")
                username_input_box.focus = true;
            else
                password_input_box.focus = true;
        }
    }

    // Hero: clock, date, location label and the minimal login card.
    // Positioned by relativePositionX/Y (fractions of the screen), sized
    // relative to the screen with the uiScale factor.
    Item {
        id: hero

        width: Math.min(parent.width * 0.92, 560 * container.uiScale)
        height: heroColumn.height
        x: parent.width * config.relativePositionX - width / 2
        y: parent.height * config.relativePositionY - height / 2

        Column {
            id: heroColumn

            width: parent.width
            spacing: 10 * container.uiScale

            Text {
                id: time

                property date dateTime: new Date()

                color: container.cream
                text: Qt.formatTime(dateTime, config.timeFormat || "hh:mm")
                font.family: container.displayFont
                font.pointSize: Math.round(parseInt(config.clockFontSize || "88", 10) * container.uiScale)
                font.weight: Font.Light
                font.letterSpacing: 2
                style: Text.Raised
                styleColor: "#66000000"

                Timer {
                    interval: 100
                    running: true
                    repeat: true
                    onTriggered: time.dateTime = new Date()
                }
            }

            Text {
                id: date

                color: container.cream
                opacity: 0.9
                text: Qt.formatDate(time.dateTime, config.dateFormat || "dddd, dd MMMM yyyy")
                font.family: container.displayFont
                font.pointSize: Math.round(parseInt(config.dateFontSize || "22", 10) * container.uiScale)
                font.weight: Font.Normal
                font.letterSpacing: 1
                style: Text.Raised
                styleColor: "#66000000"
            }

            // Signature detail: terracotta rule + letterspaced location caps.
            Row {
                spacing: 10 * container.uiScale

                Rectangle {
                    width: 26 * container.uiScale
                    height: Math.max(2, 2 * container.uiScale)
                    anchors.verticalCenter: parent.verticalCenter
                    color: container.terra
                }

                Text {
                    id: locationLabel

                    anchors.verticalCenter: parent.verticalCenter
                    color: container.muted
                    opacity: 0.9
                    text: (config.locationLabel || "Buenos Aires").toUpperCase()
                    font.family: container.displayFont
                    font.pointSize: Math.round(parseInt(config.locationFontSize || "13", 10) * container.uiScale)
                    font.weight: Font.Medium
                    font.letterSpacing: 3
                    style: Text.Raised
                    styleColor: "#66000000"
                }
            }

            // Borderless login surface: hairline fields directly on the
            // footage, no opaque card. The surface*/surfaceBorder* config
            // keys remain accepted (identity contract) but paint no chrome.
            Item {
                id: loginCard

                width: parent.width
                height: cardColumn.height + 8 * container.uiScale

                Column {
                    id: cardColumn

                    width: parent.width
                    anchors.top: parent.top
                    spacing: 12 * container.uiScale

                    Row {
                        id: identityRow

                        width: parent.width
                        height: Math.max(avatarBadge.height, nameColumn.height)
                        spacing: 12 * container.uiScale

                        Rectangle {
                            id: avatarBadge

                            width: 46 * container.uiScale
                            height: 46 * container.uiScale
                            radius: 23 * container.uiScale
                            color: "#2A1E12"
                            border.color: container.hairlineFocus
                            border.width: 1
                            clip: true
                            // Shown only when there is something to show: a
                            // configured image or a username initial.
                            visible: config.showAvatar != "false" && (username_input_box.text !== "" || avatarImage.status === Image.Ready)
                            anchors.verticalCenter: parent.verticalCenter

                            // Fallback medallion: first letter of the typed
                            // or last-used username on an earth disc.
                            Text {
                                id: avatarFallback

                                anchors.centerIn: parent
                                color: container.cream
                                text: {
                                    var name = username_input_box.text || userModel.lastUser || "";
                                    return name.length > 0 ? name.charAt(0).toUpperCase() : "";
                                }
                                font.family: container.displayFont
                                font.pointSize: Math.round(18 * container.uiScale)
                                font.weight: Font.Medium
                                visible: avatarImage.status !== Image.Ready
                            }

                            // Optional avatar file (local relative path via
                            // theme.conf). Hidden unless it loads cleanly.
                            Image {
                                id: avatarImage

                                anchors.fill: parent
                                anchors.margins: 3 * container.uiScale
                                fillMode: Image.PreserveAspectCrop
                                source: config.avatarImage || ""
                                visible: status === Image.Ready
                            }
                        }

                        Column {
                            id: nameColumn

                            width: parent.width - (avatarBadge.visible ? avatarBadge.width + parent.spacing : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4 * container.uiScale

                            Text {
                                id: username_label

                                width: parent.width
                                color: container.muted
                                opacity: 0.85
                                text: "USERNAME"
                                font.family: container.displayFont
                                font.pixelSize: Math.round(parseInt(config.labelFontSize || "11", 10) * container.uiScale)
                                font.weight: Font.Medium
                                font.letterSpacing: 2
                            }

                            TextBox {
                                id: username_input_box

                                width: parent.width
                                height: 40 * container.uiScale
                                text: userModel.lastUser
                                font: container.displayFont
                                // Faint warm wash so the input zone reads as a
                                // zone; the hairline below is the focus signal.
                                color: "#1FF4EAD8"
                                borderColor: "transparent"
                                // No SDDM focus frame: the hairline below is
                                // the focus signal (brightens on activeFocus).
                                focusColor: "transparent"
                                hoverColor: "transparent"
                                textColor: container.cream
                                Keys.onPressed: {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        sddm.login(username_input_box.text, password_input_box.text, session.index);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        password_input_box.text = "";
                                        password_input_box.focus = true;
                                        event.accepted = true;
                                    }
                                }
                                KeyNavigation.backtab: language
                                KeyNavigation.tab: password_input_box
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: username_input_box.activeFocus ? container.hairlineFocus : container.hairline
                            }
                        }
                    }

                    Text {
                        id: password_label

                        width: parent.width
                        color: container.muted
                        opacity: 0.85
                        text: textConstants.password.toUpperCase()
                        font.family: container.displayFont
                        font.pixelSize: Math.round(parseInt(config.labelFontSize || "11", 10) * container.uiScale)
                        font.weight: Font.Medium
                        font.letterSpacing: 2
                    }

                    Row {
                        id: passwordRow

                        width: parent.width
                        height: 40 * container.uiScale
                        spacing: 8 * container.uiScale

                        PasswordBox {
                            id: password_input_box

                            width: parent.width - (login_button.visible ? login_button.width + parent.spacing : 0) - (clear_passwd_button.visible ? clear_passwd_button.width + parent.spacing : 0)
                            height: parent.height
                            font: container.displayFont
                            color: "#1FF4EAD8"
                            borderColor: "transparent"
                            focusColor: "transparent"
                            hoverColor: "transparent"
                            textColor: container.cream
                            tooltipBG: "#25000000"
                            tooltipFG: "#E0573D"
                            // Absolute theme URL: SDDM resolves a relative
                            // image path against its own module directory.
                            image: Qt.resolvedUrl("components/resources/warning_red.png")
                            onTextChanged: {
                                if (password_input_box.text == "")
                                    clear_passwd_button.visible = false;

                                if (password_input_box.text != "" && config.showClearPasswordButton != "false")
                                    clear_passwd_button.visible = true;
                            }
                            Keys.onPressed: {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    sddm.login(username_input_box.text, password_input_box.text, session.index);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    password_input_box.text = "";
                                    event.accepted = true;
                                }
                            }
                            KeyNavigation.backtab: username_input_box
                            KeyNavigation.tab: login_button
                        }

                        Button {
                            id: clear_passwd_button

                            width: 34 * container.uiScale
                            height: parent.height
                            color: "transparent"
                            text: "×"
                            textColor: container.muted
                            font: container.displayFont
                            border.color: "transparent"
                            border.width: 0
                            disabledColor: "#E0573D"
                            activeColor: "#4A3A2C"
                            pressedColor: container.accent
                            onClicked: {
                                password_input_box.text = "";
                                password_input_box.focus = true;
                            }
                        }

                        // Quiet outline login key: transparent until hovered,
                        // then warm terracotta. No solid block on the footage.
                        Button {
                            id: login_button

                            width: 58 * container.uiScale
                            height: parent.height
                            color: "transparent"
                            text: "→"
                            border.color: container.hairlineFocus
                            border.width: 1
                            disabledColor: "#E0573D"
                            activeColor: container.accent
                            pressedColor: "#8F3A12"
                            textColor: container.cream
                            font.family: container.displayFont
                            font.pixelSize: Math.round(20 * container.uiScale)
                            onClicked: sddm.login(username_input_box.text, password_input_box.text, session.index)
                            KeyNavigation.backtab: password_input_box
                            KeyNavigation.tab: reboot_button
                        }
                    }

                    Rectangle {
                        width: password_input_box.width
                        height: 1
                        color: password_input_box.activeFocus ? container.hairlineFocus : container.hairline
                    }

                    Text {
                        id: error_message

                        width: parent.width
                        font.family: container.displayFont
                        font.pixelSize: Math.round(parseInt(config.errorMsgFontSize || "12", 10) * container.uiScale)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // Top bar: transparent overlay, visually secondary. Session and
    // keyboard read as quiet muted text; power glyphs sit at low opacity.
    // No opaque strip over the footage.
    Item {
        id: actionBar

        width: parent.width
        height: 36 * container.uiScale
        anchors.top: parent.top
        anchors.topMargin: 10 * container.uiScale
        visible: config.showTopBar != "false"

        Row {
            id: row_left

            anchors.left: parent.left
            anchors.leftMargin: 18 * container.uiScale
            height: parent.height
            spacing: 14 * container.uiScale

            ComboBox {
                id: session

                width: 210 * container.uiScale
                height: 20 * container.uiScale
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                arrowColor: "transparent"
                textColor: container.muted
                borderColor: "transparent"
                focusColor: container.hairlineFocus
                hoverColor: container.hairlineFocus
                font.family: container.displayFont
                font.pixelSize: Math.round(parseInt(config.actionBarFontSize || "13", 10) * container.uiScale)
                font.weight: Font.Normal
                model: sessionModel
                index: sessionModel.lastIndex
                KeyNavigation.backtab: shutdown_button
                KeyNavigation.tab: language
            }

            ComboBox {
                id: language

                model: keyboard.layouts
                index: keyboard.currentLayout
                width: 50 * container.uiScale
                height: 20 * container.uiScale
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                arrowColor: "transparent"
                borderColor: "transparent"
                focusColor: container.hairlineFocus
                hoverColor: container.hairlineFocus
                onValueChanged: keyboard.currentLayout = id
                KeyNavigation.backtab: session
                KeyNavigation.tab: username_input_box

                Connections {
                    function onCurrentLayoutChanged() {
                        combo.index = keyboard.currentLayout;
                    }

                    target: keyboard
                }

                rowDelegate: Rectangle {
                    color: "transparent"

                    Text {
                        anchors.margins: 4
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: Text.AlignVCenter
                        text: modelItem ? modelItem.modelData.shortName : "zz"
                        font.family: container.displayFont
                        font.pixelSize: Math.round(parseInt(config.actionBarFontSize || "14", 10) * container.uiScale)
                        font.bold: true
                        color: container.cream
                    }
                }
            }
        }

        Row {
            id: row_right

            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: 18 * container.uiScale
            spacing: 14 * container.uiScale

            ImageButton {
                id: reboot_button

                height: parent.height - 12 * container.uiScale
                anchors.verticalCenter: parent.verticalCenter
                source: "components/resources/reboot.svg"
                opacity: 0.7
                visible: sddm.canReboot
                onClicked: sddm.reboot()
                KeyNavigation.backtab: login_button
                KeyNavigation.tab: shutdown_button
            }

            ImageButton {
                id: shutdown_button

                height: parent.height - 12 * container.uiScale
                anchors.verticalCenter: parent.verticalCenter
                source: "components/resources/shutdown.svg"
                opacity: 0.7
                visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
                KeyNavigation.backtab: reboot_button
                KeyNavigation.tab: session
            }
        }
    }
}
