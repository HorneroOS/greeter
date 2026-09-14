// Hornero greeter (Qt6): faithful port of the upstream aerial-sddm-theme
// look — centered clock column, label-left login rows, top action bar —
// with the video source replaced by the local Argentina media catalog.
// Only intentional visual change vs upstream: local clips instead of the
// streamed Apple TV playlists (the Qt5 playlist API is gone in Qt6, and
// the greeter is offline by design). See UPSTREAM.md and docs/media-codec.md.
// No network, no shell, no absolute paths.

import QtQuick
import SddmComponents 2.0
import "components"
import "components/MediaCatalog.js" as Catalog
import "media/catalog.js" as CatalogData

Rectangle {
    // Main Container
    id: container

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index
    // Display font family (Qt6 FontLoader.name is read-only, and the
    // configured value is a family name, so bind it directly).
    property string displayFont: config.displayFont || ""

    // Inherited from SDDMComponents
    TextConstants {
        id: textConstants
    }

    // Set SDDM actions
    Connections {
        target: sddm
        function onLoginSucceeded() {
        }

        function onLoginFailed() {
            error_message.color = config.errorMsgFontColor;
            error_message.text = textConstants.loginFailed;
        }
    }

    // Background Fill
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Set Background Image
    Image {
        id: image1
        anchors.fill: parent
        //source: config.background
        fillMode: Image.PreserveAspectCrop
    }

    // Set Animated GIF Background Image
    AnimatedImage {
        id: animatedGIF1
        anchors.fill: parent
        fillMode: AnimatedImage.PreserveAspectCrop
    }

    // Background video deck (Qt6): dual MediaPlayer/VideoOutput pairs with
    // crossfade, sequenced from the local media catalog. Replaces the two
    // Qt5 players plus their opacity/transition timers; external behavior
    // is unchanged (click toggles the fader, any key reveals the login).
    // When no local clip is playable the deck stays transparent and the
    // static fallback image underneath remains visible.
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
        mainStack: login_container
        footer: login_container
    }

    // Clock and Login Area
    Rectangle {
        id: rectangle
        anchors.fill: parent
        color: "transparent"

        Column {
            id: clock
            property date dateTime: new Date()
            property color color: config.clockFontColor
            y: parent.height * config.relativePositionY - clock.height / 2
            x: parent.width * config.relativePositionX - clock.width / 2

            Timer {
                interval: 100
                running: true
                repeat: true
                onTriggered: clock.dateTime = new Date()
            }

            Text {
                id: time
                anchors.horizontalCenter: parent.horizontalCenter
                color: clock.color
                text: Qt.formatTime(clock.dateTime, config.timeFormat || "hh:mm")
                font.pointSize: config.clockFontSize
                font.family: container.displayFont
                font.bold: true
            }

            Text {
                id: date
                anchors.horizontalCenter: parent.horizontalCenter
                color: clock.color
                text: Qt.formatDate(clock.dateTime, config.dateFormat || "dddd, dd MMMM yyyy")
                font.family: container.displayFont
                font.pointSize: config.dateFontSize
                font.bold: true
            }
        }

        Rectangle {
            id: login_container
            y: clock.y + clock.height + 30
            width: clock.width
            height: parent.height * 0.08
            color: "transparent"
            anchors.left: clock.left

            Rectangle {
                id: username_row
                height: parent.height * 0.36
                color: "transparent"
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.right: parent.right
                anchors.rightMargin: 0
                transformOrigin: Item.Center
                anchors.margins: 10

                Text {
                    id: username_label
                    width: parent.width * 0.27
                    height: parent.height * 0.66
                    horizontalAlignment: Text.AlignLeft
                    font.family: container.displayFont
                    font.pixelSize: config.labelFontSize
                    font.bold: true
                    color: config.labelFontColor
                    text: "Username"
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextBox {
                    id: username_input_box
                    height: parent.height
                    text: userModel.lastUser
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: username_label.right
                    anchors.leftMargin: config.usernameLeftMargin
                    anchors.right: parent.right
                    anchors.rightMargin: 0
                    font: container.displayFont
                    color: "#25000000"
                    borderColor: "transparent"
                    textColor: config.labelFontColor

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(username_input_box.text, password_input_box.text, session.index);
                            event.accepted = true;
                        }
                    }

                    KeyNavigation.backtab: password_input_box
                    KeyNavigation.tab: password_input_box
                }
            }

            Rectangle {
                id: password_row
                y: username_row.height + 10
                height: parent.height * 0.36
                color: "transparent"
                anchors.right: parent.right
                anchors.rightMargin: 0
                anchors.left: parent.left
                anchors.leftMargin: 0

                Text {
                    id: password_label
                    width: parent.width * 0.27
                    text: textConstants.password
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font.family: container.displayFont
                    font.bold: true
                    font.pixelSize: config.labelFontSize
                    color: config.labelFontColor
                }

                PasswordBox {
                    id: password_input_box
                    height: parent.height
                    font: container.displayFont
                    color: "#25000000"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: parent.height // this sets button width, this way its a square
                    anchors.left: password_label.right
                    anchors.leftMargin: config.passwordLeftMargin
                    borderColor: "transparent"
                    textColor: config.labelFontColor
                    tooltipBG: "#25000000"
                    tooltipFG: "#dc322f"
                    // Absolute theme URL: SDDM resolves a relative image
                    // path against its own module directory.
                    image: Qt.resolvedUrl("components/resources/warning_red.png")
                    onTextChanged: {
                        if (password_input_box.text == "") {
                            clear_passwd_button.visible = false;
                        }
                        if (password_input_box.text != "" && config.showClearPasswordButton != "false") {
                            clear_passwd_button.visible = true;
                        }
                    }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(username_input_box.text, password_input_box.text, session.index);
                            event.accepted = true;
                        }
                    }

                    KeyNavigation.backtab: username_input_box
                    KeyNavigation.tab: login_button
                }

                Button {
                    id: clear_passwd_button
                    height: parent.height
                    width: parent.height
                    color: "transparent"
                    text: "x"
                    textColor: config.labelFontColor
                    font: container.displayFont

                    border.color: "transparent"
                    border.width: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.leftMargin: 0
                    anchors.rightMargin: parent.height

                    disabledColor: "#dc322f"
                    activeColor: "#393939"
                    pressedColor: "#2aa198"

                    onClicked: {
                        password_input_box.text = "";
                        password_input_box.focus = true;
                    }
                }

                Button {
                    id: login_button
                    height: parent.height
                    color: "#393939"
                    text: ">"
                    border.color: "#00000000"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: password_input_box.right
                    anchors.right: parent.right
                    disabledColor: "#dc322f"
                    activeColor: "#268bd2"
                    pressedColor: "#2aa198"
                    textColor: config.labelFontColor
                    font: container.displayFont

                    onClicked: sddm.login(username_input_box.text, password_input_box.text, session.index)

                    KeyNavigation.backtab: password_input_box
                    KeyNavigation.tab: reboot_button
                }

                Text {
                    id: error_message
                    height: parent.height
                    font.family: container.displayFont
                    font.pixelSize: config.errorMsgFontSize
                    font.bold: true
                    //color: "white"
                    anchors.top: password_input_box.bottom
                    anchors.left: password_input_box.left
                    anchors.leftMargin: 0
                }
            }
        }
    }

    // Top Bar
    Rectangle {
        id: actionBar
        width: parent.width
        height: parent.height * 0.04
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        color: "transparent"
        visible: config.showTopBar != "false"

        Row {
            id: row_left
            anchors.left: parent.left
            anchors.margins: 5
            height: parent.height
            spacing: 10

            ComboBox {
                id: session
                width: 145
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                arrowColor: "transparent"
                textColor: config.actionBarFontColor
                borderColor: "transparent"
                hoverColor: "#5692c4"
                font.family: container.displayFont
                font.pixelSize: config.actionBarFontSize
                font.bold: true

                model: sessionModel
                index: sessionModel.lastIndex

                KeyNavigation.backtab: shutdown_button
                KeyNavigation.tab: password_input_box
            }

            ComboBox {
                id: language

                model: keyboard.layouts
                index: keyboard.currentLayout
                width: 50
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                arrowColor: "transparent"
                //textColor: "white"
                borderColor: "transparent"
                hoverColor: "#5692c4"

                onValueChanged: keyboard.currentLayout = id

                Connections {
                    target: keyboard

                    function onCurrentLayoutChanged() {
                        combo.index = keyboard.currentLayout;
                    }
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
                        font.pixelSize: config.actionBarFontSize
                        font.bold: true
                        color: config.actionBarFontColor
                    }
                }
                KeyNavigation.backtab: session
                KeyNavigation.tab: username_input_box
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
    }
}
