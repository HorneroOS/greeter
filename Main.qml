// Hornero cinematic greeter (Qt6).
// Visual identity: warm charcoal surfaces, earth browns, terracotta and
// burnt-orange accents, cream type. The background video hero plays under a
// warm grade (tint wash, vertical gradient, side vignette) with a large
// clock, date, subtle location label and one minimal login card.
// All layout is relative to the screen size so 720p, 1080p, 1440p and HiDPI
// scale from the same file. No network, no shell, no absolute paths.

import QtQuick
import SddmComponents 2.0
import "components"
import "components/MediaCatalog.js" as Catalog

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
    // Display font family (Qt6 FontLoader.name is read-only, and the
    // configured value is a family name, so bind it directly).
    property string displayFont: config.displayFont || ""

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    Component.onCompleted: {
        deck.focus = true;
        // Static fallback image (local file only), layered under the deck.
        var hour = new Date().getHours();
        var isDaytime = Catalog.isDay(hour, config.dayTimeStart, config.dayTimeEnd);
        var stillImage = isDaytime ? config.bgImgDay : config.bgImgNight;
        if (stillImage !== null && stillImage !== undefined && stillImage !== "") {
            var fileType = stillImage.substring(stillImage.lastIndexOf(".") + 1).toLowerCase();
            if (fileType === "gif")
                animatedGIF1.source = stillImage;
            else
                image1.source = stillImage;
        }
        deck.daypart = isDaytime ? "day" : "night";
        // Local media catalog (media/catalog.json). A missing or invalid
        // catalog simply leaves the static image visible.
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return ;

            if (xhr.status !== 200 && xhr.status !== 0)
                return ;

            var raw = null;
            try {
                raw = JSON.parse(xhr.responseText);
            } catch (e) {
                return ;
            }
            if (!Catalog.validateCatalog(raw).ok)
                return ;

            var resolve = function resolve(list) {
                return list.map(function(e) {
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
                    "night": resolve(raw.dayparts.night)
                }
            };
        };
        xhr.open("GET", Qt.resolvedUrl(config.mediaManifest || "media/catalog.json"));
        xhr.send();
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

                anchors.horizontalCenter: parent.horizontalCenter
                color: container.cream
                text: Qt.formatTime(dateTime, config.timeFormat || "hh:mm")
                font.family: container.displayFont
                font.pointSize: Math.round(parseInt(config.clockFontSize || "72", 10) * container.uiScale)
                font.bold: true
                style: Text.Raised
                styleColor: "#80000000"

                Timer {
                    interval: 100
                    running: true
                    repeat: true
                    onTriggered: time.dateTime = new Date()
                }

            }

            Text {
                id: date

                anchors.horizontalCenter: parent.horizontalCenter
                color: container.cream
                opacity: 0.92
                text: Qt.formatDate(time.dateTime, config.dateFormat || "dddd, dd MMMM yyyy")
                font.family: container.displayFont
                font.pointSize: Math.round(parseInt(config.dateFontSize || "24", 10) * container.uiScale)
                font.bold: true
                style: Text.Raised
                styleColor: "#80000000"
            }

            Text {
                id: locationLabel

                anchors.horizontalCenter: parent.horizontalCenter
                color: container.muted
                opacity: 0.85
                text: config.locationLabel || "Buenos Aires"
                font.family: container.displayFont
                font.pointSize: Math.round(parseInt(config.locationFontSize || "14", 10) * container.uiScale)
                font.bold: false
                style: Text.Raised
                styleColor: "#80000000"
            }

            Rectangle {
                id: loginCard

                width: parent.width
                height: cardColumn.height + 28 * container.uiScale
                color: container.surface
                radius: 14 * container.uiScale
                border.color: container.surfaceBorder
                border.width: 1

                Column {
                    id: cardColumn

                    width: parent.width - 32 * container.uiScale
                    anchors.centerIn: parent
                    spacing: 10 * container.uiScale

                    Row {
                        id: identityRow

                        width: parent.width
                        height: Math.max(avatarBadge.height, nameColumn.height)
                        spacing: 12 * container.uiScale

                        Rectangle {
                            id: avatarBadge

                            width: 56 * container.uiScale
                            height: 56 * container.uiScale
                            radius: 10 * container.uiScale
                            color: "#4A3A2C"
                            border.color: container.terra
                            border.width: 1
                            clip: true
                            visible: config.showAvatar != "false"
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
                                font.pointSize: Math.round(22 * container.uiScale)
                                font.bold: true
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
                                text: "Username"
                                font.family: container.displayFont
                                font.pixelSize: Math.round(parseInt(config.labelFontSize || "16", 10) * container.uiScale)
                                font.bold: true
                            }

                            TextBox {
                                id: username_input_box

                                width: parent.width
                                height: 34 * container.uiScale
                                text: userModel.lastUser
                                font: container.displayFont
                                color: "#25000000"
                                borderColor: "transparent"
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

                        }

                    }

                    Text {
                        id: password_label

                        width: parent.width
                        color: container.muted
                        text: textConstants.password
                        font.family: container.displayFont
                        font.pixelSize: Math.round(parseInt(config.labelFontSize || "16", 10) * container.uiScale)
                        font.bold: true
                    }

                    Row {
                        id: passwordRow

                        width: parent.width
                        height: 34 * container.uiScale
                        spacing: 8 * container.uiScale

                        PasswordBox {
                            id: password_input_box

                            width: parent.width - (login_button.visible ? login_button.width + parent.spacing : 0) - (clear_passwd_button.visible ? clear_passwd_button.width + parent.spacing : 0)
                            height: parent.height
                            font: container.displayFont
                            color: "#25000000"
                            borderColor: "transparent"
                            textColor: container.cream
                            tooltipBG: "#25000000"
                            tooltipFG: "#E0573D"
                            image: "components/resources/warning_red.png"
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
                            text: "x"
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

                        Button {
                            id: login_button

                            width: 64 * container.uiScale
                            height: parent.height
                            color: container.accent
                            text: ">"
                            border.color: "#00000000"
                            disabledColor: "#E0573D"
                            activeColor: container.terra
                            pressedColor: "#8F3A12"
                            textColor: container.cream
                            font: container.displayFont
                            onClicked: sddm.login(username_input_box.text, password_input_box.text, session.index)
                            KeyNavigation.backtab: password_input_box
                            KeyNavigation.tab: reboot_button
                        }

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

    // Top Bar
    Rectangle {
        id: actionBar

        width: parent.width
        height: Math.max(parent.height * 0.04, 28 * container.uiScale)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#66000000"
        visible: config.showTopBar != "false"

        Row {
            id: row_left

            anchors.left: parent.left
            anchors.margins: 5
            height: parent.height
            spacing: 10

            ComboBox {
                id: session

                width: 210 * container.uiScale
                height: 20 * container.uiScale
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                arrowColor: "transparent"
                textColor: container.cream
                borderColor: "transparent"
                hoverColor: "#5692c4"
                font.family: container.displayFont
                font.pixelSize: Math.round(parseInt(config.actionBarFontSize || "14", 10) * container.uiScale)
                font.bold: true
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
                hoverColor: "#5692c4"
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
            anchors.margins: 5
            spacing: 10

            ImageButton {
                id: reboot_button

                height: parent.height
                source: "components/resources/reboot.svg"
                visible: sddm.canReboot
                onClicked: sddm.reboot()
                KeyNavigation.backtab: login_button
                KeyNavigation.tab: shutdown_button
            }

            ImageButton {
                id: shutdown_button

                height: parent.height
                source: "components/resources/shutdown.svg"
                visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
                KeyNavigation.backtab: reboot_button
                KeyNavigation.tab: session
            }

        }

    }

}
