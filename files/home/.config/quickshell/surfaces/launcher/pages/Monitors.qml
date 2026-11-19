pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils

BasePage {
    id: root

    showSearchbar: false
    enableSearchbar: false
    showSearchbarOverlay: false
    outerMargins: 0

    pageName: "Monitors"
    pageIcon: "monitor"
    pageIconType: "symbol"

    property var localMonitors: []
    property bool needsUpdate: false
    property int selectedIndex: 0
    property bool isDirty: false
    property var dirtyMonitorNames: []

    // Pure helpers
    function monitorDims(m) {
        const isRotated = m.transform % 2 !== 0;
        return {
            w: (isRotated ? m.height : m.width) / m.scale,
            h: (isRotated ? m.width : m.height) / m.scale
        };
    }

    function getAspectRatio(w, h) {
        const gcd = (a, b) => b === 0 ? a : gcd(b, a % b);
        const d = gcd(w, h);
        let rw = w / d, rh = h / d;

        const standards = [[16, 9], [16, 10], [21, 9], [32, 9], [4, 3], [5, 4], [3, 2], [1, 1]];
        const actual = w / h;
        const tolerance = 0.02;

        const match = standards.find(([sw, sh]) => Math.abs(actual - sw / sh) < tolerance);
        if (match) {
            rw = match[0];
            rh = match[1];
        }

        return `${rw}:${rh}`;
    }

    // Main monitor is fully name-based via GlobalSettings.mainMonitor.
    // No id === 0 fallback: ensureMainMonitor() backfills from localMonitors.
    function isMainMonitor(m) {
        return !!m && m.name === GlobalSettings.mainMonitor;
    }
    function setMainMonitor(name) {
        if (name && name !== GlobalSettings.mainMonitor)
            GlobalSettings.mainMonitor = name;
    }
    function ensureMainMonitor() {
        if (root.localMonitors.length === 0)
            return;
        const names = root.localMonitors.map(m => m.name);
        if (!GlobalSettings.mainMonitor || !names.includes(GlobalSettings.mainMonitor))
            GlobalSettings.mainMonitor = names[0];
    }

    // Navigation
    function nextItem() {
        if (root.localMonitors.length > 0)
            root.selectedIndex = (root.selectedIndex + 1) % root.localMonitors.length;
    }

    function previousItem() {
        if (root.localMonitors.length > 0)
            root.selectedIndex = (root.selectedIndex - 1 + root.localMonitors.length) % root.localMonitors.length;
    }

    function primaryAction() {
        if (root.isDirty)
            root.applyChanges();
    }

    // Data management
    function syncFromService() {
        root.localMonitors = JSON.parse(JSON.stringify(MonitorService.monitors));
        root.ensureMainMonitor();
        root.needsUpdate = false;
        root.isDirty = false;
        root.dirtyMonitorNames = [];
        if (root.localMonitors.length > 0) {
            root.selectedIndex = 0;
            updateStack();
        }
    }

    function applyChanges() {
        if (MonitorService.busy || MonitorService.showConfirmPopup) return;
        MonitorService.setMonitors(root.localMonitors, root.dirtyMonitorNames);
    }

    function updateStack() {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.localMonitors.length)
            settingsStack.replace(settingsComponent, {
                monitorIndex: root.selectedIndex
            });
    }

    function updateMonitor(index, fields) {
        const updated = root.localMonitors.slice();
        updated[index] = Object.assign({}, updated[index], fields);
        const name = updated[index].name;
        if (name && !root.dirtyMonitorNames.includes(name))
            root.dirtyMonitorNames = root.dirtyMonitorNames.concat(name);
        root.localMonitors = updated;
        root.isDirty = true;
    }

    // Lifecycle
    Component.onCompleted: root.syncFromService()
    onSelectedIndexChanged: updateStack()

    Connections {
        target: MonitorService
        function onDataChangedChanged() {
            if (MonitorService.showConfirmPopup)
                return;
            if (!root.isDirty)
                root.syncFromService();
            else
                root.needsUpdate = true;
        }
        function onShowConfirmPopupChanged() {
            if (!MonitorService.showConfirmPopup) root.syncFromService();
        }
    }

    // Layout
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Left: Preview (65%)
        Item {
            id: previewArea
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.65
            clip: true

            property real layoutMinX: 0
            property real layoutMaxX: 0
            property real layoutMinY: 0
            property real layoutMaxY: 0
            property real layoutWidth: 0
            property real layoutHeight: 0
            property real scaleFactor: 1

            function updateLayout() {
                if (!root.localMonitors.length) {
                    layoutMinX = layoutMinY = layoutWidth = layoutHeight = 0;
                    scaleFactor = 1;
                    return;
                }
                let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
                root.localMonitors.forEach(m => {
                    const d = root.monitorDims(m);
                    minX = Math.min(minX, m.x);
                    maxX = Math.max(maxX, m.x + d.w);
                    minY = Math.min(minY, m.y);
                    maxY = Math.max(maxY, m.y + d.h);
                });
                layoutMinX = minX;
                layoutMaxX = maxX;
                layoutMinY = minY;
                layoutMaxY = maxY;
                layoutWidth = maxX - minX;
                layoutHeight = maxY - minY;
                scaleFactor = Math.min((previewArea.width - 40) / layoutWidth, (previewArea.height - 40) / layoutHeight);
            }

            // Snap the dragged monitor to edges/centers of all other monitors,
            // then reject the snap if it would cause any overlap.
            function snapPosition(dragIndex, rawX, rawY) {
                const dragged = root.localMonitors[dragIndex];
                const dd = root.monitorDims(dragged);

                let bestX = rawX, bestY = rawY;
                let bestDist = Infinity;

                root.localMonitors.forEach((m, i) => {
                    if (i === dragIndex)
                        return;
                    const md = root.monitorDims(m);

                    const xCandidates = [m.x, m.x - dd.w, m.x + md.w, m.x + md.w - dd.w, m.x + (md.w - dd.w) / 2];
                    const yCandidates = [m.y, m.y - dd.h, m.y + md.h, m.y + md.h - dd.h, m.y + (md.h - dd.h) / 2];

                    // Pick the best (cx, cy) pair by combined distance
                    xCandidates.forEach(cx => {
                        yCandidates.forEach(cy => {
                            const dist = Math.abs(rawX - cx) + Math.abs(rawY - cy);
                            if (dist < bestDist) {
                                bestDist = dist;
                                bestX = cx;
                                bestY = cy;
                            }
                        });
                    });
                });

                const snappedX = Math.round(bestX);
                const snappedY = Math.round(bestY);

                const overlaps = root.localMonitors.some((m, i) => {
                    if (i === dragIndex)
                        return false;
                    const md = root.monitorDims(m);
                    return snappedX < m.x + md.w && snappedX + dd.w > m.x && snappedY < m.y + md.h && snappedY + dd.h > m.y;
                });

                if (overlaps)
                    return {
                        x: dragged.x,
                        y: dragged.y
                    };

                return {
                    x: snappedX,
                    y: snappedY
                };
            }

            onWidthChanged: updateLayout()
            onHeightChanged: updateLayout()

            Connections {
                target: root
                function onLocalMonitorsChanged() {
                    previewArea.updateLayout();
                }
            }

            Item {
                anchors.centerIn: parent
                width: previewArea.layoutWidth * previewArea.scaleFactor
                height: previewArea.layoutHeight * previewArea.scaleFactor

                Repeater {
                    model: root.localMonitors
                    delegate: StyledRectangle {
                        id: monitorRect
                        required property var modelData
                        required property int index

                        readonly property var dims: root.monitorDims(modelData)
                        readonly property bool isSelected: root.selectedIndex === index
                        readonly property bool isDisabled: modelData.disabled ?? false
                        readonly property bool isDragged: dragArea.drag.active
                        readonly property bool isMain: root.isMainMonitor(modelData)

                        x: (modelData.x - previewArea.layoutMinX) * previewArea.scaleFactor
                        y: (modelData.y - previewArea.layoutMinY) * previewArea.scaleFactor
                        z: isDragged ? 100 : isSelected ? 99 : index
                        width: dims.w * previewArea.scaleFactor
                        height: dims.h * previewArea.scaleFactor

                        color: isSelected ? Theme.colors.color4 : Theme.colors.bgSurface
                        border.color: isSelected ? Theme.colors.color6 : Theme.colors.borderMid
                        border.width: 1
                        baseRadius: 0
                        opacity: isDisabled ? 0.4 : 1.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animations.duration.normal
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: monitorRect.modelData.name
                            font.pixelSize: Theme.fontPixelSizes.smaller
                            font.weight: Font.Bold
                            opacity: monitorRect.isDisabled ? 0.6 : 1.0
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: monitorRect.isMain ? null : monitorRect
                            cursorShape: monitorRect.isMain ? Qt.ArrowCursor : Qt.SizeAllCursor

                            onPressed: {
                                root.selectedIndex = monitorRect.index;
                            }

                            onReleased: {
                                if (monitorRect.isMain)
                                    return;

                                const expectedX = (monitorRect.modelData.x - previewArea.layoutMinX) * previewArea.scaleFactor;
                                const expectedY = (monitorRect.modelData.y - previewArea.layoutMinY) * previewArea.scaleFactor;

                                if (monitorRect.x === expectedX && monitorRect.y === expectedY)
                                    return;

                                const rawMonX = monitorRect.x / previewArea.scaleFactor + previewArea.layoutMinX;
                                const rawMonY = monitorRect.y / previewArea.scaleFactor + previewArea.layoutMinY;
                                const snapped = previewArea.snapPosition(monitorRect.index, rawMonX, rawMonY);

                                if (snapped.x !== monitorRect.modelData.x || snapped.y !== monitorRect.modelData.y) {
                                    root.updateMonitor(monitorRect.index, {
                                        x: snapped.x,
                                        y: snapped.y
                                    });
                                    monitorRect.x = (snapped.x - previewArea.layoutMinX) * previewArea.scaleFactor;
                                    monitorRect.y = (snapped.y - previewArea.layoutMinY) * previewArea.scaleFactor;
                                    Qt.callLater(() => {
                                        monitorRect.x = Qt.binding(() => (monitorRect.modelData.x - previewArea.layoutMinX) * previewArea.scaleFactor);
                                        monitorRect.y = Qt.binding(() => (monitorRect.modelData.y - previewArea.layoutMinY) * previewArea.scaleFactor);
                                    });
                                } else {
                                    monitorRect.x = Qt.binding(() => (monitorRect.modelData.x - previewArea.layoutMinX) * previewArea.scaleFactor);
                                    monitorRect.y = Qt.binding(() => (monitorRect.modelData.y - previewArea.layoutMinY) * previewArea.scaleFactor);
                                }
                            }
                        }

                        // Main monitor selector (above dragArea so it receives clicks)
                        StyledIconButton {
                            iconName: "star"
                            iconFilled: monitorRect.isMain
                            enabled: !monitorRect.isMain
                            showBackground: false
                            width: 32
                            height: 32
                            iconSize: 36
                            iconWeight: 200
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            onClicked: {
                                root.selectedIndex = monitorRect.index;
                                root.setMainMonitor(monitorRect.modelData.name);
                            }
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: ColorUtils.transparentize(Theme.colors.white, 0.15)
        }

        // Right: Settings (35%)
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.35
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                StyledText {
                    text: "Settings"
                    font.pixelSize: Theme.fontPixelSizes.large
                    font.weight: Font.Bold
                }

                StyledText {
                    text: root.localMonitors[root.selectedIndex]?.name ?? ""
                    font.pixelSize: Theme.fontPixelSizes.smaller
                    color: Theme.colors.textSecondary
                    horizontalAlignment: Text.AlignLeft
                    font.weight: Font.Medium
                    Layout.leftMargin: 4
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledIconButton {
                    iconName: "refresh"
                    iconSize: 22
                    visible: root.needsUpdate
                    Layout.preferredHeight: 22
                    onClicked: {
                        root.syncFromService();
                        GlobalIpc.popup.showInfo("Display Settings Refreshed", "", 2000);
                    }
                }

                StyledIconButton {
                    iconName: "download"
                    visible: root.isDirty
                    Layout.preferredHeight: 32
                    onClicked: root.applyChanges()
                }
            }

            StackView {
                id: settingsStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                pushEnter: null
                pushExit: null
                popEnter: null
                popExit: null
                replaceEnter: null
                replaceExit: null
            }
        }
    }

    // Reusable: Axis offset control
    component AxisControl: ColumnLayout {
        id: axisControl
        required property string label
        required property int value
        required property int monitorIndex
        required property string axis

        StyledText {
            text: axisControl.label
            font.pixelSize: Theme.fontPixelSizes.smallest
            color: Theme.colors.textMuted
        }
        RowLayout {
            StyledIconButton {
                iconName: "remove"
                iconSize: 20
                alwaysShowBackground: true
                holdToRepeat: true
                onClicked: root.updateMonitor(axisControl.monitorIndex, {
                    [axisControl.axis]: axisControl.value - 10
                })
            }

            StyledText {
                text: axisControl.value.toString()
                Layout.preferredWidth: 40
            }

            StyledIconButton {
                iconName: "add"
                iconSize: 20
                alwaysShowBackground: true
                holdToRepeat: true
                onClicked: root.updateMonitor(axisControl.monitorIndex, {
                    [axisControl.axis]: axisControl.value + 10
                })
            }
        }
    }

    component SectionDivider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: ColorUtils.transparentize(Theme.colors.white, 0.1)
    }

    // Settings panel
    Component {
        id: settingsComponent
        ListView {
            id: settingsPage
            required property int monitorIndex
            readonly property var monitor: root.localMonitors[monitorIndex]
            readonly property bool isMain: root.isMainMonitor(monitor)

            model: monitor ? 1 : 0
            clip: true

            delegate: ColumnLayout {
                width: settingsPage.width
                spacing: 12

                // Status (non-main only, main monitor is set via the preview star)
                ColumnLayout {
                    visible: !settingsPage.isMain
                    spacing: 12

                    StyledText {
                        text: "Status"
                        font.weight: Font.Medium
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: "Monitor Enabled"
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                        }

                        StyledSwitch {
                            checked: !settingsPage.monitor.disabled
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 26
                            onCheckedChanged: {
                                if (checked !== !settingsPage.monitor.disabled)
                                    root.updateMonitor(settingsPage.monitorIndex, {
                                        disabled: !checked
                                    });
                            }
                        }
                    }

                }

                SectionDivider {
                    visible: !settingsPage.isMain
                }

                // Resolution & Rate
                ColumnLayout {
                    spacing: 8

                    StyledText {
                        text: "Resolution & Rate"
                        font.weight: Font.Medium
                        color: Theme.colors.textSecondary
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        showScrollBar: false
                        colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                        model: settingsPage.monitor.availableModes.map(mode => {
                            const parts = mode.split("x");
                            const w = parseInt(parts[0]);
                            const h = parseInt(parts[1].split("@")[0]);
                            return {
                                text: `${mode} (${root.getAspectRatio(w, h)})`,
                                value: mode
                            };
                        })
                        currentIndex: {
                            const current = `${settingsPage.monitor.width}x${settingsPage.monitor.height}@${settingsPage.monitor.refreshRate}`;
                            return model.findIndex(m => m.value === current);
                        }
                        onActivated: {
                            const mode = model[currentIndex].value;
                            const [wStr, rest] = mode.split("x");
                            const [hStr, rStr] = rest.split("@");
                            root.updateMonitor(settingsPage.monitorIndex, {
                                width: parseInt(wStr),
                                height: parseInt(hStr),
                                refreshRate: parseFloat(rStr)
                            });
                        }
                        popup.onVisibleChanged: {
                            if (!popup.visible)
                                root.forceActiveFocus();
                        }
                    }
                }

                SectionDivider {
                    Layout.topMargin: 8
                }

                // Scale
                ColumnLayout {
                    spacing: 8

                    StyledText {
                        text: "Scale"
                        font.weight: Font.Medium
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        spacing: 12
                        Repeater {
                            model: [0.75, 1, 1.25, 1.5, 2]
                            delegate: StyledIconButton {
                                required property var modelData
                                readonly property bool active: settingsPage.monitor?.scale === modelData
                                iconMode: "text"
                                textLabel: modelData % 1 === 0 ? modelData.toFixed(0) + "×" : modelData + "×"
                                iconSize: Theme.fontPixelSizes.smaller + 1
                                textWeight: Font.DemiBold
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                alwaysShowBackground: active
                                backgroundTransparency: active ? 0.50 : 0.10
                                backgroundColor: active ? Theme.colors.primary : Theme.colors.white
                                inactiveOpacity: active ? 1 : 0.5
                                onClicked: root.updateMonitor(settingsPage.monitorIndex, {
                                    scale: modelData
                                })
                            }
                        }
                    }
                }

                SectionDivider {}

                // Rotation
                ColumnLayout {
                    spacing: 8

                    StyledText {
                        text: "Rotation"
                        font.weight: Font.Medium
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        spacing: 12
                        Repeater {
                            model: [0, 1, 2, 3]
                            delegate: StyledIconButton {
                                required property int modelData
                                readonly property bool active: settingsPage.monitor?.transform === modelData
                                iconName: "desktop_windows"
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                rotation: modelData * 90
                                alwaysShowBackground: active
                                backgroundTransparency: active ? 0.50 : 0.10
                                backgroundColor: active ? Theme.colors.primary : Theme.colors.white
                                inactiveOpacity: active ? 1 : 0.5
                                onClicked: root.updateMonitor(settingsPage.monitorIndex, {
                                    transform: modelData
                                })
                            }
                        }
                    }
                }

                SectionDivider {}

                // Positioning
                ColumnLayout {
                    spacing: 8

                    StyledText {
                        text: "Positioning"
                        font.weight: Font.Medium
                        color: Theme.colors.textSecondary
                    }

                    RowLayout {
                        spacing: 8
                        AxisControl {
                            label: "X Offset"
                            axis: "x"
                            value: settingsPage.monitor.x
                            monitorIndex: settingsPage.monitorIndex
                        }
                        AxisControl {
                            label: "Y Offset"
                            axis: "y"
                            value: settingsPage.monitor.y
                            monitorIndex: settingsPage.monitorIndex
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.preferredHeight: 20
                }
            }
        }
    }

    // Confirmation Popup Overlay
    Rectangle {
        id: confirmOverlay
        anchors.fill: parent
        visible: MonitorService.showConfirmPopup
        color: ColorUtils.transparentize(Theme.colors.bgBase, 0.70)
        z: 99

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Keys.onEscapePressed: event => event.accepted = true

        StyledRectangle {
            id: confirmCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 480)
            implicitHeight: confirmColumn.implicitHeight + 48
            shadow: true
            color: Theme.colors.bgSurface
            baseRadius: Theme.rounding.verylarge
            border.color: Theme.colors.borderFrameMid
            border.width: 1
            scale: 0.95
            opacity: 0

            ColumnLayout {
                id: confirmColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                StyledText {
                    text: "Keep Display Changes?"
                    font.pixelSize: Theme.fontPixelSizes.large
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }

                StyledText {
                    id: confirmDesc
                    text: "Changes will be reverted in " + MonitorService.confirmTimer + " seconds."
                    font.pixelSize: Theme.fontPixelSizes.normal
                    color: Theme.colors.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                    spacing: 0

                    StyledButton {
                        Layout.preferredWidth: (confirmCard.width - 44) / 2
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignLeft
                        text: "Revert"
                        onClicked: MonitorService.revertChanges()
                        border.width: 1
                        border.color: Theme.colors.borderFrameMid
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledButton {
                        Layout.preferredWidth: (confirmCard.width - 44) / 2
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignRight
                        text: "Keep Changes"
                        backgroundColor: Theme.colors.primary
                        onClicked: MonitorService.keepChanges()
                        border.width: 1
                        border.color: Theme.colors.color7
                    }
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Easing.OutCubic
                }
            }
            Component.onCompleted: {
                scale = 1;
                opacity = 1;
            }
        }
    }
}
