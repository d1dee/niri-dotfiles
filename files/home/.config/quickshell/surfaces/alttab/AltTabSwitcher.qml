pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import "../../lib/ColorUtils.js" as ColorUtils
import "../../lib/AppUtils.js" as AppUtils

PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === NiriService.focusedOutput) ?? Quickshell.screens[0]

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:alttabswitcher"
    anchors {
      top: true
      bottom: true
      right: true
      left: true
    }

    property bool show: false

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: root.show = true
    }

    StyledRectangle {
        id: background
        visible: root.show
        anchors.centerIn: parent
        implicitWidth: root.screen.width * 0.75
        implicitHeight: root.screen.height * 0.75
        color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase
        shadow: true
        baseRadius: Theme.rounding.large
        border.color: Theme.colors.borderFrameMid
        border.width: 1
    }

    Item {
        id: container
        anchors.fill: background
        anchors.margins: Math.min(48, background.width * 0.04)
        opacity: root.show && AltTabService.flattenedToplevels.length > 0 ? 1 : 0
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Alt) {
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                if (event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)) {
                    AltTabService.switchPrevious();
                } else {
                    AltTabService.switchNext();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                AltTabService.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                AltTabService.activateSelected();
                event.accepted = true;
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt) {
                AltTabService.activateSelected();
                event.accepted = true;
            }
        }

        Item {
            id: indicators
            implicitWidth: parent.width
            implicitHeight: AltTabService.windowPages.length > 1 ? 64 : 0
            visible: AltTabService.windowPages.length > 1
            anchors.top: parent.top

            Row {
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: AltTabService.windowPages.length
                    StyledRectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: swipeable.currentIndex === index ? 24 : 12
                        height: 12
                        baseRadius: 6
                        color: swipeable.currentIndex === index ? Theme.colors.color16 : Theme.colors.textSecondary
                        opacity: swipeable.currentIndex === index ? 1 : 0.4

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animations.duration.normal
                                easing.type: Theme.animations.easing.outCubic
                            }
                        }
                    }
                }
            }
        }

        SwipeView {
            id: swipeable
            implicitWidth: parent.width
            implicitHeight: parent.height - indicators.height
            anchors.bottom: parent.bottom
            spacing: 48
            interactive: true

            function syncPage() {
                setCurrentIndex(Math.floor(AltTabService.selectedIndex / AltTabService.itemsPerPage));
            }
            Component.onCompleted: syncPage()

            Connections {
                target: AltTabService
                function onSelectedIndexChanged() {
                    swipeable.syncPage();
                }
                function onWindowPagesChanged() {
                    Qt.callLater(swipeable.syncPage);
                }
            }

            Repeater {
                model: AltTabService.windowPages

                Item {
                    id: windowPageItem
                    required property var modelData
                    required property int index
                    implicitWidth: swipeable.width
                    implicitHeight: swipeable.height
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 32

                        Repeater {
                            model: windowPageItem.modelData

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 32

                                Repeater {
                                    model: parent.modelData

                                    Item {
                                        id: toplevelItem
                                        required property var modelData
                                        readonly property int flatIndex: AltTabService.getToplevelFlatIndex(modelData)
                                        readonly property bool isSelected: flatIndex === AltTabService.selectedIndex

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true

                                        StyledClippingRectangle {
                                            id: proportionalRect

                                            property bool isHovered: false

                                            anchors.centerIn: parent
                                            border.color: toplevelItem.isSelected ? Theme.colors.white : isHovered ? Theme.colors.textMuted : Theme.colors.borderMid
                                            border.width: 1
                                            color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgSurface, 0.6) : Theme.colors.bgSurface
                                            baseRadius: Theme.rounding.normal + 2

                                            width: toplevelItem.width
                                            height: toplevelItem.height

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: AltTabService.selectAndActivate(toplevelItem.flatIndex)
                                                onEntered: proportionalRect.isHovered = true
                                                onExited: proportionalRect.isHovered = false
                                            }
                                        }

                                        StyledIcon {
                                            iconName: AppUtils.getAppIcon(toplevelItem.modelData.app_id, [...new Set(DesktopEntries.applications.values)])
                                            iconSize: Math.max(24, Math.min(64, proportionalRect.height * 0.35))
                                            useIconTheme: true
                                            placeHolder: "applications-system"
                                            anchors.horizontalCenter: proportionalRect.horizontalCenter
                                            anchors.verticalCenter: proportionalRect.verticalCenter
                                            anchors.verticalCenterOffset: -titleTag.height / 2
                                        }

                                        StyledRectangle {
                                            id: titleTag
                                            implicitHeight: titleText.implicitHeight + 12
                                            implicitWidth: Math.min(titleText.implicitWidth + 24, proportionalRect.width - 24)
                                            anchors.bottom: proportionalRect.bottom
                                            anchors.horizontalCenter: proportionalRect.horizontalCenter
                                            anchors.bottomMargin: 12
                                            color: Theme.colors.bgElevated
                                            baseRadius: height / 2
                                            border.width: 1
                                            border.color: Theme.colors.borderMid

                                            StyledText {
                                                id: titleText
                                                anchors.centerIn: parent
                                                text: toplevelItem.modelData.title || toplevelItem.modelData.app_id || "Untitled window"
                                                font.pixelSize: Theme.fontPixelSizes.small
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                width: parent.width - 16
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
