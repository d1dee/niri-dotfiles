pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components

PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) ?? Quickshell.screens[0]

    property alias notificationListView: notificationListView
    property int margin: 8 + 8

    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.isNotificationActionsMenuOpenVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
    }

    implicitWidth: Theme.sizes.notificationPopupWidth + (margin * 4)
    color: "transparent"

    mask: Region {
        readonly property real headerH: notificationListView.headerItem?.height ?? 0
        readonly property real delegatesH: Math.max(0, notificationListView.contentHeight - headerH)

        y: headerH
        width: root.implicitWidth
        height: delegatesH
    }

    StyledListView {
        id: notificationListView
        opacity: GlobalCache.loadLockScreen || ["controlcenter", "battery"].includes(GlobalStates.expandedBarModule.toLowerCase()) ? 0 : 1
        anchors.fill: parent
        spacing: root.margin / 2
        transitionStyle: "popup"
        popupOpacityFrom: 1.0
        popupScaleFrom: 0.0
        animateInDuration: 300
        animateOutDuration: 300
        showScrollBar: false

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outCubic
            }
        }

        header: Item {
            width: notificationListView.width
            // Match the ordinary bar layout; Niri IPC has no fullscreen metadata.
            height: ((GlobalStates.showBar && GlobalSettings.loadBar && !GlobalSettings.hideTopBar) ? Theme.sizes.barHeight : 0) + root.margin

            Behavior on height {
                NumberAnimation {
                    duration: notificationListView.displacedDuration
                    easing.type: Easing.OutExpo
                }
            }
        }

        model: ScriptModel {
            id: notificationListViewModel
            values: NotificationService.activeNotificationsList
        }

        delegate: NotificationItem {
            id: notificationItem
            required property var modelData
            required property int index
            notification: modelData
            visible: modelData
            anchors.right: parent?.right
            anchors.rightMargin: root.margin
            transformOrigin: Item.Top
        }
    }
}
