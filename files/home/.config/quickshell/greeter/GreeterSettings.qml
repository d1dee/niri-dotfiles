pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property var _excluded: new Set(["objectName", "objectNameChanged", "children", "reloadableId"])
    property var _jsonData: {
        try {
            return JSON.parse(settingsJson.text());
        } catch (e) {
            return {};
        }
    }
    property bool _ready: false

    property string lastGreeterUser: _jsonData.lastGreeterUser || ""
    property string lastGreeterSession: _jsonData.lastGreeterSession || "niri"
    property bool blurGreeter: _jsonData.blurGreeter ?? true

    Component.onCompleted: {
        for (var prop in root) {
            if (typeof root[prop] === "function")
                continue;
            if (prop[0] === "_")
                continue;
            var signalName = prop + "Changed";
            if (root[signalName] !== undefined) {
                root[signalName].connect(() => saveTimer.restart());
            }
        }
        _ready = true;
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.save()
    }

    FileView {
        id: settingsJson
        path: Paths.greeterSettingsJsonFile
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    function collectData() {
        var data = {};
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
        settingsJson.setData(JSON.stringify(collectData(), null, 2));
    }
}
