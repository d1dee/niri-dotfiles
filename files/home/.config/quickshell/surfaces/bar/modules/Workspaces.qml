pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils

BarModule {
    id: root
    name: "workspaces"
    baseWidth: (workspaceIndicatorWidth * workspacesToShow) + (workspaceIndicatorSpacing * workspacesToShow) - workspaceIndicatorOuterGap
    enableClickToExpand: false

    readonly property int workspacesToShow: 9
    readonly property int workspaceIndicatorSpacing: 8
    readonly property int workspaceIndicatorOuterGap: 4
    readonly property int workspaceIndicatorWidth: Theme.sizes.barModuleBaseHeight - workspaceIndicatorOuterGap

    required property string outputName
    readonly property var sortedWorkspaces: NiriService.workspaces.filter(ws => ws.output === outputName).sort((a, b) => a.idx - b.idx)
    readonly property int focusedIndex: sortedWorkspaces.findIndex(ws => ws.is_active)
    readonly property int currentGroup: focusedIndex >= 0 ? Math.floor(focusedIndex / workspacesToShow) : 0
    readonly property int groupStart: currentGroup * workspacesToShow
    readonly property var currentGroupWorkspaces: sortedWorkspaces.slice(groupStart, groupStart + workspacesToShow)
    readonly property int localFocusedIndex: focusedIndex >= 0 ? focusedIndex - groupStart : -1
    readonly property int focusIndicatorX: localFocusedIndex >= 0 ? (workspaceIndicatorOuterGap / 2) + localFocusedIndex * (workspaceIndicatorWidth + workspaceIndicatorSpacing) : (workspaceIndicatorOuterGap / 2)

    readonly property var paddedGroupWorkspaces: {
        const arr = currentGroupWorkspaces.slice();
        while (arr.length < workspacesToShow)
            arr.push({
                _isPadding: true
            });
        return arr;
    }

    component WorkspaceIndicator: StyledRectangle {
        id: workspaceIndicator
        required property var modelData
        required property int index
        readonly property bool isReal: modelData && !modelData._isPadding
        property bool isHovered: false

        baseRadius: width / 2
        implicitWidth: root.workspaceIndicatorWidth
        implicitHeight: root.workspaceIndicatorWidth
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: isHovered ? ColorUtils.transparentize(Theme.colors.color16, 0.10) : "transparent"

        StyledText {
            text: parent.isReal ? parent.modelData.idx : ""
            anchors.centerIn: parent
            opacity: parent.isReal ? 1.0 : 0.35
            font.weight: Font.DemiBold
            font.family: Theme.fontFamilies.main
            font.pixelSize: Theme.fontPixelSizes.small
        }

        MouseArea {
            enabled: parent.isReal
            visible: enabled
            anchors.fill: parent
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onEntered: workspaceIndicator.isHovered = true
            onExited: workspaceIndicator.isHovered = false
            onClicked: NiriService.focusWorkspace(parent.modelData.id)
        }

        Behavior on color {
            ColorAnimation {
                duration: 300
                easing.type: Easing.OutExpo
            }
        }
    }

    initialContent: Item {
        id: container
        StyledRectangle {
            id: focusIndicator
            visible: root.localFocusedIndex >= 0
            width: root.workspaceIndicatorWidth
            height: root.workspaceIndicatorWidth
            baseRadius: width / 2
            color: ColorUtils.transparentize(Theme.colors.color8, 0.60)
            x: root.focusIndicatorX
            y: (parent.height - height) / 2

            StyledRectangle {
                anchors.fill: parent
                baseRadius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: ColorUtils.transparentize(Theme.colors.white, 0.10)
            }

            Behavior on x {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutExpo
                }
            }
        }

        Row {
            id: list
            anchors.fill: parent
            anchors.leftMargin: root.workspaceIndicatorOuterGap / 2
            anchors.rightMargin: root.workspaceIndicatorOuterGap / 2
            spacing: root.workspaceIndicatorSpacing

            Repeater {
                model: root.paddedGroupWorkspaces
                delegate: WorkspaceIndicator {}
            }
        }
    }
}
