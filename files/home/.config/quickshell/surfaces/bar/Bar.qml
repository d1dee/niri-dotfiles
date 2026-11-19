pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import qs.surfaces.bar.modules
import "../../lib/ColorUtils.js" as ColorUtils

Scope {
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) ?? Quickshell.screens[0]

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: Theme.sizes.barHeight
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Theme.sizes.barHeight

        WlrLayershell.namespace: "quickshell:bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {}
        color: "transparent"
        visible: GlobalStates.showBar && !GlobalSettings.hideTopBar
    }

    PanelWindow {
        id: rootSurface
        screen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) ?? Quickshell.screens[0]

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        readonly property string maskTarget: GlobalStates.expandedBarModule
        readonly property Item maskItem: maskTarget === "dateTime" ? dateTimeModule : maskTarget === "background" ? background : maskTarget === "workspaces" ? workspacesModule : maskTarget === "resources" ? resourcesModule : maskTarget === "mprisPlayers" ? mprisPlayersModule : maskTarget === "weather" ? weatherModule : maskTarget === "controlCenter" ? controlCenterModule : maskTarget === "battery" ? batteryModule : null
        // Niri IPC does not expose fullscreen/maximized state for automatic compaction.
        readonly property bool compactBar: GlobalSettings.forceCompactBar
        property bool revealHovered: false
        readonly property bool barRevealed: GlobalSettings.hideTopBar && !GlobalCache.loadLockScreen && (revealHovered || GlobalStates.expandedBarModule !== "")
        readonly property bool barHidden: GlobalSettings.hideTopBar && !GlobalCache.loadLockScreen && !barRevealed

        exclusionMode: ExclusionMode.Ignore
        visible: GlobalStates.showBar && background.anchors.topMargin >= -Theme.sizes.barHeight - 1
        color: "transparent"

        WlrLayershell.namespace: "quickshell:bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: (GlobalStates.expandedBarModule !== "" || PolkitService.active) && rootSurface.screen?.name === NiriService.focusedOutput ? WlrKeyboardFocus.Exclusive : GlobalSettings.hideTopBar ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

        mask: Region {
            item: rootSurface.maskItem === null ? rootSurface.maskItem : contentRow
            height: rootSurface.maskItem === null ? (rootSurface.barHidden ? 1 : Theme.sizes.barHeight) : 0
            width: rootSurface.maskItem === null ? rootSurface.width : 0
        }

        Item {
            id: revealArea

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: rootSurface.barRevealed ? Theme.sizes.barHeight : 1
            z: 100

            HoverHandler {
                acceptedButtons: Qt.NoButton
                blocking: false

                onHoveredChanged: rootSurface.revealHovered = hovered
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: rootSurface.maskTarget !== ""
            visible: enabled
            onClicked: GlobalStates.expandedBarModule = ""
        }

        StyledRectangle {
            id: background

            readonly property real calculatedTopMargin: (rootSurface.compactBar ? 0 : contentRow.margin) + ((Theme.sizes.barHeight - Theme.sizes.barModuleBaseHeight) / 2) - gap
            property int gap: 3

            implicitHeight: Theme.sizes.barModuleBaseHeight + (gap * 2)
            height: rootSurface.compactBar ? Theme.sizes.barHeight : implicitHeight

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: (GlobalCache.loadLockScreen || rootSurface.barHidden) ? -Theme.sizes.barHeight - 1 : (rootSurface.compactBar ? 0 : calculatedTopMargin)
            anchors.leftMargin: contentRow.anchors.leftMargin - gap
            anchors.rightMargin: contentRow.anchors.rightMargin - gap

            baseRadius: rootSurface.compactBar ? 0 : implicitHeight - gap
            color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.88) : Theme.colors.bgBase
            opacity: rootSurface.compactBar ? 1 : 0

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.animations.duration.verySlow
                    easing.type: Theme.animations.easing.outExpo
                }
            }

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: rootSurface.barHidden ? Theme.animations.duration.fast : Theme.animations.duration.slow
                    easing.type: Theme.animations.easing.outQuad
                }
            }

            Rectangle {
                height: 1
                width: parent.width
                anchors.top: parent.bottom
                color: Theme.colors.borderFrame
                opacity: rootSurface.compactBar && (!GlobalCache.loadLockScreen || GlobalSettings.hideTopBar) ? 1 : 0
            }
        }

        Rectangle {
            id: overlay

            color: rootSurface.maskItem === null ? "transparent" : ColorUtils.transparentize(Theme.colors.black, 0.14)
            anchors.fill: parent

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.Linear
                }
            }
        }

        Item {
            id: contentRow

            readonly property int gap: 10
            readonly property int margin: 4
            readonly property real normalMargin: (rootSurface.compactBar ? 0 : margin) + (Theme.sizes.barHeight - Theme.sizes.barModuleBaseHeight) / 2
            readonly property real hiddenMargin: -Theme.sizes.barHeight

            focus: true
            anchors.fill: parent
            anchors.topMargin: (GlobalCache.loadLockScreen || rootSurface.barHidden) ? hiddenMargin : normalMargin
            anchors.leftMargin: normalMargin
            anchors.rightMargin: normalMargin
            Keys.onEscapePressed: GlobalStates.expandedBarModule = ""

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: rootSurface.barHidden ? Theme.animations.duration.fast : Theme.animations.duration.slow
                    easing.type: Theme.animations.easing.outQuad
                }
            }

            Workspaces {
                id: workspacesModule
                outputName: rootSurface.screen?.name ?? ""
                anchors.left: parent.left
                anchors.leftMargin: isExpanded ? contentRow.margin : 0
                compactBar: rootSurface.compactBar
            }

            Resources {
                id: resourcesModule
                x: Math.max(workspacesModule.baseWidth + contentRow.gap + (baseWidth / 2) - (implicitWidth / 2), 0)
                compactBar: rootSurface.compactBar
            }

            MprisPlayers {
                id: mprisPlayersModule
                x: parent.width / 2 - dateTimeModule.baseWidth / 2 - baseWidth / 2 - implicitWidth / 2 - contentRow.gap
                compactBar: rootSurface.compactBar
            }

            DateTime {
                id: dateTimeModule
                x: parent.width / 2 - implicitWidth / 2
                compactBar: rootSurface.compactBar
            }

            Weather {
                id: weatherModule
                x: parent.width / 2 + dateTimeModule.baseWidth / 2 + baseWidth / 2 - implicitWidth / 2 + contentRow.gap
                compactBar: rootSurface.compactBar
            }

            ControlCenter {
                id: controlCenterModule
                x: parent.width - batteryModule.baseWidth - contentRow.gap - (baseWidth / 2) - (implicitWidth / 2)
                baseWidth: (workspacesModule.baseWidth + resourcesModule.baseWidth) - (Theme.sizes.barModuleBaseHeight)
                compactBar: rootSurface.compactBar
            }

            Battery {
                id: batteryModule
                anchors.right: parent.right
                anchors.rightMargin: isExpanded ? contentRow.margin : 0
                compactBar: rootSurface.compactBar
            }
        }
    }
}
