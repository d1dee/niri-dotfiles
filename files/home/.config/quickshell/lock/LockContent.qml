pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.services
import qs.components
import qs.lock
import qs
import "../lib/ColorUtils.js" as ColorUtils

WlSessionLock {
    id: root
    locked: LockService.locked

    onSecureChanged: LockService.acquired = root.secure
    Component.onDestruction: LockService.acquired = false

    readonly property var inputScreen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) || Quickshell.screens[0] || null

    surface: WlSessionLockSurface {
        id: rootSurface
        color: Theme.colors.bgBase
        property bool wallpaperIsGif: GlobalData.wallpaperPath.endsWith(".gif")
        property bool isMainMonitor: rootSurface.screen === root.inputScreen

        Rectangle {
            anchors.fill: parent
            color: LockService.showUI ? ColorUtils.transparentize(Theme.colors.black, 0.25) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animations.duration.slowest
                    easing.type: Theme.animations.easing.outQuad
                }
            }
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
                        source: Qt.resolvedUrl(Paths.wallpaperWebp)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: LockService.showUI && status === Image.Ready ? 1 : 0
                        visible: !GlobalSettings.blurLockscreen && !rootSurface.wallpaperIsGif

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animations.duration.slowest
                                easing.type: Theme.animations.easing.outQuad
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl(Paths.wallpaperWebp)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        antialiasing: true
                        mipmap: true
                        cache: false
                        sourceSize.width: 960
                        sourceSize.height: 540
                        opacity: sharpImage.opacity
                        visible: GlobalSettings.blurLockscreen && status === Image.Ready

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
            visible: rootSurface.wallpaperIsGif
            anchors.fill: parent
            active: visible
            z: -2

            sourceComponent: Component {
                AnimatedImage {
                    anchors.fill: parent
                    source: Qt.resolvedUrl(GlobalData.wallpaperPath)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    playing: LockService.showUI && !GlobalSettings.blurLockscreen
                    opacity: LockService.showUI && status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animations.duration.slowest
                            easing.type: Theme.animations.easing.outQuad
                        }
                    }
                }
            }
        }

        Loader {
            id: mainMonitorLoader
            active: rootSurface.isMainMonitor
            anchors.fill: parent
            onLoaded: item.forceActiveFocus()
            z: 0

            sourceComponent: Component {
                FocusScope {
                    anchors.fill: parent

                    Item {
                        anchors.fill: parent
                        visible: rootSurface.isMainMonitor
                        enabled: visible

                        StyledText {
                            id: time
                            font.pixelSize: 116
                            text: Qt.formatDateTime(ClockService.systemClock.date, "hh:mm")
                            renderType: Text.NativeRendering
                            font.weight: Font.Bold
                            font.family: Theme.fontFamilies.outfit
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 54
                            opacity: LockService.showUI ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.slower
                                    easing.type: Theme.animations.easing.outQuad
                                }
                            }
                        }

                        StyledText {
                            font.pixelSize: 20
                            text: Qt.formatDateTime(ClockService.systemClock.date, "dddd, MMM dd")
                            renderType: Text.NativeRendering
                            font.weight: Font.DemiBold
                            font.family: Theme.fontFamilies.outfit
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: time.bottom
                            anchors.topMargin: -8
                            opacity: LockService.showUI ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.verySlow
                                    easing.type: Theme.animations.easing.outQuad
                                }
                            }
                        }

                        StyledText {
                            text: "Unlocking failed, please try again."
                            font.pixelSize: Theme.fontPixelSizes.small
                            font.weight: Font.DemiBold
                            font.family: Theme.fontFamilies.main
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16 + 50 + 12 + (LockService.hasFailed ? 0 : -8)
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            opacity: LockService.hasFailed ? 1 : 0
                            color: Theme.colors.textSecondary

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
                            height: 40
                            width: row.implicitWidth + 20

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: 12
                            anchors.leftMargin: 12

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconName: WeatherService.data.current.weather_material_symbol
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: WeatherService.data.current.temperature.toFixed(0) + "°"
                                    font.pixelSize: Theme.fontPixelSizes.small
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Bubble {
                            id: batteryBubble

                            readonly property UPowerDevice battery: UPower.devices.values.length > 0 ? UPower.devices.values[0] : null
                            readonly property int pct: Math.round(battery.percentage * 100)
                            readonly property bool isCharging: battery.state === UPowerDeviceState.Charging
                            readonly property bool isFullyCharged: battery.state === UPowerDeviceState.FullyCharged || (battery.state === UPowerDeviceState.PendingCharge && BatteryService.autoManageEnabled)
                            readonly property bool isCritical: pct <= 15 && !isCharging && !isFullyCharged
                            readonly property bool isWarning: pct <= 25 && !isCharging && !isCritical && !isFullyCharged
                            readonly property color accent: isCharging ? Theme.colors.success : isWarning ? Theme.colors.warning : isCritical ? Theme.colors.error : Theme.colors.white

                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 12
                            anchors.rightMargin: 12

                            height: 40
                            width: row.implicitWidth + 20

                            color: (!isCharging && !isWarning && !isCritical) ? ColorUtils.transparentize(accent, 0.10) : ColorUtils.transparentize(ColorUtils.mix(accent, Theme.colors.bgBase, 0.30), 0.70)
                            border.color: ColorUtils.transparentize(accent, 0.25)
                            visible: battery.ready && battery.isLaptopBattery

                            Row {
                                id: row
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: batteryBubble.accent
                                    filled: true
                                    iconName: {
                                        if (batteryBubble.isFullyCharged && BatteryService.autoManageEnabled)
                                            return "battery_android_shield";
                                        if (batteryBubble.isFullyCharged || batteryBubble.pct >= 100)
                                            return "battery_android_full";
                                        if (batteryBubble.pct <= 5)
                                            return "battery_android_0";
                                        if (batteryBubble.pct <= 20)
                                            return "battery_android_1";
                                        if (batteryBubble.pct <= 35)
                                            return "battery_android_2";
                                        if (batteryBubble.pct <= 50)
                                            return "battery_android_3";
                                        if (batteryBubble.pct <= 65)
                                            return "battery_android_4";
                                        if (batteryBubble.pct <= 80)
                                            return "battery_android_5";
                                        if (batteryBubble.pct <= 90)
                                            return "battery_android_6";
                                        return "battery_android_full";
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: batteryBubble.pct + "%"
                                    font.pixelSize: Theme.fontPixelSizes.small
                                    font.weight: Font.DemiBold
                                    color: batteryBubble.accent
                                }
                            }
                        }

                        Bubble {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            width: (LockService.isAuthenticating || !LockService.showUI || passwordInput.text.length === 0) ? height : 250
                            opacity: LockService.lockInput ? 0 : 1
                            height: 50

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.standard
                                    easing.type: Theme.animations.easing.outCubic
                                }
                            }

                            MaterialSymbol {
                                id: lockIcon
                                iconSize: 24
                                iconName: LockService.showUI ? "lock" : "lock_open_right"
                                opacity: 1 - passwordInput.opacity
                                anchors.centerIn: parent
                                color: Theme.colors.white
                                layer.enabled: true
                                layer.smooth: true

                                RotationAnimator on rotation {
                                    running: LockService.isAuthenticating
                                    from: 0
                                    to: 360
                                    duration: Theme.animations.duration.veryLong
                                    easing.type: Easing.Linear
                                    loops: Animation.Infinite
                                    onFinished: lockIcon.rotation = 0
                                }
                            }

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.margins: 8
                                color: Theme.colors.white
                                font.family: Theme.fontFamilies.main
                                font.pixelSize: Theme.fontPixelSizes.larger
                                echoMode: TextInput.Password
                                focus: true
                                clip: true
                                readOnly: LockService.lockInput
                                enabled: !LockService.isAuthenticating
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                cursorDelegate: Item {}
                                opacity: (LockService.isAuthenticating || !LockService.showUI || text.length === 0) ? 0 : 1
                                selectedTextColor: Theme.colors.textPrimary
                                selectionColor: ColorUtils.transparentize(Theme.colors.white, 0.15)
                                leftPadding: 0
                                rightPadding: 0

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape && !LockService.lockInput)
                                        passwordInput.clear();

                                    if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_B && !LockService.lockInput)
                                        GlobalSettings.blurLockscreen = !GlobalSettings.blurLockscreen;

                                    if (event.modifiers & Qt.ControlModifier && event.modifiers & Qt.AltModifier && event.key === Qt.Key_L) {
                                        if (!LockService.isAuthenticating) {
                                            passwordInput.clear();
                                            LockService.lockInput = !LockService.lockInput;
                                        }
                                    }
                                }

                                onAccepted: {
                                    if (text.length > 0)
                                        LockService.submit();
                                }

                                onEnabledChanged: {
                                    if (enabled) {
                                        forceActiveFocus();
                                        selectAll();
                                    }
                                }

                                // Fix tty change that blocks input
                                InfiniteTimer {
                                    interval: 5000
                                    onTriggered: if (!passwordInput.focus)
                                        passwordInput.forceActiveFocus()
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.animations.duration.standard
                                        easing.type: Theme.animations.easing.outCubic
                                    }
                                }

                                Binding {
                                    target: LockService
                                    property: "passwordInput"
                                    value: passwordInput.text
                                }

                                Connections {
                                    target: LockService
                                    function onPasswordInputChanged() {
                                        passwordInput.text = LockService.passwordInput;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Bubble: StyledRectangle {
        id: bubble

        color: ColorUtils.transparentize(Theme.colors.white, 0.10)
        border.color: ColorUtils.transparentize(Theme.colors.white, 0.25)
        baseRadius: height / 2
        border.width: 1
        opacity: LockService.showUI ? 1 : 0

        Behavior on width {
            NumberAnimation {
                duration: Theme.animations.duration.standard
                easing.type: Theme.animations.easing.outBack
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.slower
                easing.type: Theme.animations.easing.outQuad
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.slowest
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }
}
