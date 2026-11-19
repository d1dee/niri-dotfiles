pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

ControlCenterPage {
    id: root

    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 24

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            spacing: 12

            StyledText {
                text: "Brightness"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 12

                StyledText {
                    text: "Night Light"
                    font.pixelSize: Theme.fontPixelSizes.small
                    font.weight: Font.Medium
                    opacity: BrightnessService.nightLightEnabled ? 1.0 : 0.4

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animations.duration.normal
                        }
                    }
                }

                StyledSwitch {
                    implicitWidth: 64
                    implicitHeight: 28
                    checked: BrightnessService.nightLightEnabled
                    onClicked: BrightnessService.toggleNightLight()
                }
            }
        }

        // Content
        StyledListView {
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            smoothScrollEnabled: false
            showScrollBar: false
            interactive: false
            spacing: 24
            model: BrightnessService.monitors

            delegate: ColumnLayout {
                id: delegate
                required property var modelData
                width: ListView.view.width
                spacing: 4

                StyledText {
                    text: parent.modelData.screen.name
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignLeft
                    Layout.fillWidth: true
                    Layout.leftMargin: slider.radiusBig
                    opacity: 0.6
                }

                StyledSlider {
                    id: slider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    iconName: BrightnessService.materialSymbol
                    leftBorder: false
                    value: delegate.modelData.brightness
                    animationEnabled: false
                    onMoved: delegate.modelData.setBrightness(value)
                    from: 0.01
                    to: 1.0
                    showValue: true
                    valueText: Math.round(delegate.modelData.brightness * 100) + "%"

                    Timer {
                        interval: 200
                        running: true
                        repeat: false
                        onTriggered: parent.animationEnabled = true
                    }
                }
            }
        }
    }
}
