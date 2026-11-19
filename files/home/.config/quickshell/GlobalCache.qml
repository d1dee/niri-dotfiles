pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // Internal
    readonly property var _excluded: new Set(["objectName", "objectNameChanged", "children", "reloadableId"])
    property bool _ready: false

    // Cache props session-scoped
    property string inhibitorState: ""
    property bool lowBatteryNotified: false
    property bool wasInhibitActive: false
    property bool loadLockScreen: false
    property var notificationTimestamps: ({})
    property var unreadNotificationsIds: []
    property var pickedColors: []
    property var countdown: ({})
    property var stopwatch: ({})
    property int powerProfile: 1
    property int controlCenterExpandableIndex: -1
    property int controlCenterBarIndex: -1

    Component.onCompleted: {
        var saved = {};
        try {
            var parsed = JSON.parse(cacheFile.text());
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                saved = parsed;
        } catch (e) {}

        if (saved?.processId === Quickshell.processId) {
            for (var prop in saved) {
                if (prop === "processId")
                    continue;
                if (root[prop] !== undefined)
                    root[prop] = saved[prop];
            }
        }

        // Connect all prop signals to debounced save
        for (var p in root) {
            if (typeof root[p] === "function")
                continue;
            if (p[0] === "_")
                continue;

            var signalName = p + "Changed";
            if (root[signalName] !== undefined)
                root[signalName].connect(() => saveTimer.restart());
        }

        _ready = true;
        save();
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.save()
    }

    FileView {
        id: cacheFile
        path: Qt.resolvedUrl(Paths.cacheJsonFile)
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    function collectData() {
        var data = {
            processId: Quickshell.processId
        };
        for (var prop in root) {
            if (typeof root[prop] === "function")
                continue;
            if (prop[0] === "_")
                continue;
            if (root._excluded.has(prop))
                continue;
            if (prop.endsWith("Changed"))
                continue;
            data[prop] = root[prop];
        }
        return data;
    }

    function save() {
        if (!_ready)
            return;
        cacheFile.setData(JSON.stringify(collectData(), null, 2));
    }
}
