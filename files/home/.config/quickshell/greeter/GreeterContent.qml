pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.components
import qs.greeter
import qs
import "../lib/ColorUtils.js" as ColorUtils

Rectangle {
    id: root
    anchors.fill: parent
    color: Theme.colors.color2

    readonly property string wallpaperPath: GlobalData.wallpaperPath || Paths.defaultWallpaper
    readonly property string wallpaperImagePath: GlobalData.wallpaperWebpPath || wallpaperPath
    readonly property string wallpaperVersion: GlobalData.wallpaperContentHash || wallpaperPath
    readonly property string wallpaperImageSource: Qt.resolvedUrl(wallpaperImagePath) + "?v=" + encodeURIComponent(wallpaperVersion)
    readonly property string wallpaperAnimatedSource: Qt.resolvedUrl(wallpaperPath) + "?v=" + encodeURIComponent(wallpaperVersion)
    readonly property bool wallpaperIsGif: wallpaperPath.endsWith(".gif")

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Loader {
        anchors.fill: parent
        z: -1

        sourceComponent: Component {
            Item {
                anchors.fill: parent

                Image {
                    id: sharpImage
                    anchors.fill: parent
                    source: root.wallpaperImageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: status === Image.Ready ? 1 : 0
                    visible: !GreeterSettings.blurGreeter && !root.wallpaperIsGif

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animations.duration.slowest
                            easing.type: Theme.animations.easing.outQuad
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.wallpaperImageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 960
                    sourceSize.height: 540
                    opacity: sharpImage.opacity
                    visible: GreeterSettings.blurGreeter && status === Image.Ready

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 84
                        blurMultiplier: 4.25
                        autoPaddingEnabled: false
                    }
                }
            }
        }
    }

    Loader {
        visible: root.wallpaperIsGif
        anchors.fill: parent
        active: visible
        z: -2

        sourceComponent: Component {
            AnimatedImage {
                anchors.fill: parent
                source: root.wallpaperAnimatedSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                playing: !GreeterSettings.blurGreeter
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.slowest
                        easing.type: Theme.animations.easing.outQuad
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Theme.colors.black, 0.25)

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.slowest
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }

    StyledText {
        id: time
        font.pixelSize: 116
        text: Qt.formatDateTime(clock.date, "hh:mm")
        renderType: Text.NativeRendering
        font.weight: Font.Bold
        font.family: Theme.fontFamilies.outfit
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 54
    }

    StyledText {
        font.pixelSize: 20
        text: Qt.formatDateTime(clock.date, "dddd, MMM dd")
        renderType: Text.NativeRendering
        font.weight: Font.DemiBold
        font.family: Theme.fontFamilies.outfit
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: time.bottom
        anchors.topMargin: -8
    }

    Bubble {
        id: userBubble
        height: 40
        width: userRow.implicitWidth + 20

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12
        anchors.leftMargin: 12

        RowLayout {
            id: userRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconName: "person"
                color: Theme.colors.white
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: userCombo.currentValue ? userCombo.currentValue.text : ""
                font.pixelSize: Theme.fontPixelSizes.small
                font.weight: Font.DemiBold
                font.family: Theme.fontFamilies.main
                elide: Text.ElideNone
            }
        }

        BubbleComboBox {
            id: userCombo
            anchors.fill: parent
            model: GreeterService.users
            popupWidth: Math.max(((Math.max(...GreeterService.users.map(s => s.text.length), 0)) * Theme.fontPixelSizes.small / 1.5) + 20, userBubble.width)
            onActivated: GreeterSettings.lastGreeterUser = currentValue.text

            onModelChanged: {
                if (GreeterSettings.lastGreeterUser !== "") {
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].text === GreeterSettings.lastGreeterUser) {
                            currentIndex = i;
                            break;
                        }
                    }
                }
            }
        }
    }

    Bubble {
        id: sessionBubble
        height: 40
        width: sessionRow.implicitWidth + 20

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12

        RowLayout {
            id: sessionRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconName: "desktop_windows"
                color: Theme.colors.white
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: sessionCombo.currentValue ? sessionCombo.currentValue.text : ""
                font.pixelSize: Theme.fontPixelSizes.small
                font.weight: Font.DemiBold
                font.family: Theme.fontFamilies.main
            }
        }

        BubbleComboBox {
            id: sessionCombo
            anchors.fill: parent
            model: GreeterService.sessions
            popupAlignRight: true
            popupWidth: Math.max(((Math.max(...GreeterService.sessions.map(s => s.text.length), 0)) * Theme.fontPixelSizes.small / 1.5) + 20, sessionBubble.width)
            onActivated: GreeterSettings.lastGreeterSession = currentValue.text

            onModelChanged: {
                if (GreeterSettings.lastGreeterSession !== "") {
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].text === GreeterSettings.lastGreeterSession) {
                            currentIndex = i;
                            break;
                        }
                    }
                }
            }
        }
    }

    StyledText {
        id: statusText
        font.pixelSize: Theme.fontPixelSizes.small
        font.weight: Font.DemiBold
        font.family: Theme.fontFamilies.main
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16 + 50 + 12 + (GreeterService.authenticationHasFailed ? 0 : -8)
        horizontalAlignment: Text.AlignHCenter
        width: parent.width
        color: Theme.colors.textSecondary
        opacity: (GreeterService.authenticationHasFailed || GreeterService.awaitingResponse) ? 1 : 0
        wrapMode: Text.WordWrap

        text: GreeterService.echoResponse || "Authentication failed"

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.verySlow
                easing.type: Theme.animations.easing.outCubic
            }
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Theme.animations.duration.verySlow
                easing.type: Theme.animations.easing.outCubic
            }
        }
    }

    Bubble {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: (GreeterService.isAuthenticating || passwordField.text.length === 0) ? height : 250
        height: 50

        MaterialSymbol {
            id: lockIcon
            iconName: "lock"
            opacity: 1 - passwordField.opacity
            anchors.centerIn: parent
            color: Theme.colors.white

            RotationAnimator on rotation {
                running: GreeterService.isAuthenticating
                from: 0
                to: 360
                duration: Theme.animations.duration.veryLong
                easing.type: Easing.Linear
                loops: Animation.Infinite
                onFinished: lockIcon.rotation = 0
            }
        }

        TextInput {
            id: passwordField
            anchors.centerIn: parent
            width: parent.width
            color: Theme.colors.white
            font.family: Theme.fontFamilies.main
            font.pixelSize: Theme.fontPixelSizes.larger
            echoMode: (GreeterService.awaitingResponse && GreeterService.responseEcho) ? TextInput.Normal : TextInput.Password
            focus: true
            clip: true
            enabled: !GreeterService.isAuthenticating
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            cursorDelegate: Item {}
            opacity: (GreeterService.isAuthenticating || text.length === 0) ? 0 : 1
            selectedTextColor: Theme.colors.textPrimary
            selectionColor: ColorUtils.transparentize(Theme.colors.white, 0.15)
            leftPadding: 8
            rightPadding: 8
            Component.onCompleted: forceActiveFocus()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    passwordField.clear();
                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_B)
                    GreeterSettings.blurGreeter = !GreeterSettings.blurGreeter;
            }

            onAccepted: {
                const user = userCombo.currentValue;
                const session = sessionCombo.currentValue;
                GreeterService.login(user ? user.text : "", text, session ? session.exec : [], session ? session.type : "", session ? session.sessionDesktop : "", session ? session.desktopNames : []);
                clear();
            }

            onEnabledChanged: {
                if (enabled) {
                    forceActiveFocus();
                    selectAll();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.standard
                    easing.type: Theme.animations.easing.outCubic
                }
            }
        }
    }

    Bubble {
        id: blurToggleBubble
        height: 40
        width: height

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 12

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: GreeterSettings.blurGreeter = !GreeterSettings.blurGreeter
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconName: GreeterSettings.blurGreeter ? "blur_on" : "blur_off"
            color: Theme.colors.white
        }
    }

    Bubble {
        id: powerBubble
        height: 40
        width: height

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 12

        MaterialSymbol {
            anchors.centerIn: parent
            iconName: "power_settings_new"
            color: Theme.colors.white
        }

        BubbleComboBox {
            id: powerMenu
            anchors.fill: parent
            popupWidth: 180
            model: [
                {
                    text: "Sleep",
                    icon: "dark_mode",
                    action: () => GreeterService.suspend()
                },
                {
                    text: "Restart",
                    icon: "rotate_right",
                    action: () => GreeterService.restart()
                },
                {
                    text: "Restart to Bios",
                    icon: "build",
                    action: () => GreeterService.restartToBios()
                },
                {
                    text: "Shut Down",
                    icon: "power_settings_new",
                    action: () => GreeterService.powerOff()
                }
            ]

            onActivated: index => {
                model[index].action();
            }
        }
    }

    component Bubble: StyledClippingRectangle {
        color: ColorUtils.transparentize(Theme.colors.white, 0.10)
        border.color: ColorUtils.transparentize(Theme.colors.white, 0.25)
        baseRadius: height / 2
        border.width: 1
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animations.duration.standard
                easing.type: Theme.animations.easing.outBack
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.slowest
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }

    component BubbleComboBox: StyledComboBox {
        opacity: 0
        currentIndex: 0
        radius: (height / 2) + 4
        colorBgPopup: ColorUtils.transparentize(Theme.colors.white, 0.05)
        colorBorderOpen: ColorUtils.transparentize(Theme.colors.white, 0.25)
        colorHighlitedPopup: ColorUtils.transparentize(Theme.colors.white, 0.125)
        popup.onVisibleChanged: if (!popup.visible)
            passwordField.forceActiveFocus()
    }
}
