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
    property var _jsonData: {
        var data = {};
        try {
            var parsed = JSON.parse(dataJson.text());
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                data = parsed;
        } catch (e) {}
        // One-time migration: fall back to legacy values still in settings.json
        try {
            var legacy = JSON.parse(settingsJson.text());
            if (!legacy || typeof legacy !== "object" || Array.isArray(legacy))
                legacy = {};
            for (var key of ["emojiScores", "launcherSuggestionsScores", "calculatorHistory", "desktopWidgetData", "processesSortCriteria", "lastUpdateCheck", "wallpaperPath", "wallpaperWebpPath", "isRecording", "recordingRegion"]) {
                if (data[key] === undefined && legacy[key] !== undefined)
                    data[key] = legacy[key];
            }
        } catch (e) {}
        return data;
    }
    property bool _ready: false

    // Durable app data mirror of data.json (auto-written, not user prefs)
    property bool isRecording: _jsonData.isRecording ?? false
    property var recordingRegion: _jsonData.recordingRegion || null
    property string wallpaperPath: _jsonData.wallpaperPath || ""
    property string wallpaperWebpPath: _jsonData.wallpaperWebpPath || ""
    property string wallpaperContentHash: _jsonData.wallpaperContentHash || ""
    property double lastUpdateCheck: _jsonData.lastUpdateCheck || 0
    property string processesSortCriteria: _jsonData.processesSortCriteria || "cpu"
    property var desktopWidgetData: {
        var d = _jsonData.desktopWidgetData;
        return Object.assign({
            x: 0,
            y: 0,
            brightness: 0,
            textColor: "light"
        }, (d && typeof d === "object" && !Array.isArray(d)) ? d : {});
    }
    property var calculatorHistory: Array.isArray(_jsonData.calculatorHistory) ? _jsonData.calculatorHistory : []
    property var launcherSuggestionsScores: (_jsonData.launcherSuggestionsScores && typeof _jsonData.launcherSuggestionsScores === "object" && !Array.isArray(_jsonData.launcherSuggestionsScores)) ? _jsonData.launcherSuggestionsScores : ({})
    property var emojiScores: (_jsonData.emojiScores && typeof _jsonData.emojiScores === "object" && !Array.isArray(_jsonData.emojiScores)) ? _jsonData.emojiScores : ({})

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
        save();
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.save()
    }

    Connections {
        target: root
        function onIsRecordingChanged() {
            if (!root.isRecording)
                root.recordingRegion = null;
        }
    }

    FileView {
        id: dataJson
        path: Paths.dataJsonFile
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    FileView {
        id: settingsJson
        path: Paths.settingsJsonFile
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
        if (!_ready || Paths.isGreeter)
            return;
        dataJson.setData(JSON.stringify(collectData()));
    }
}
