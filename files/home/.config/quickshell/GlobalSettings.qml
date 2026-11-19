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
        try {
            var data = JSON.parse(settingsJson.text());
            return (data && typeof data === "object" && !Array.isArray(data)) ? data : {};
        } catch (e) {
            return {};
        }
    }
    property bool _ready: false

    // Settings mirror of settings.json
    property bool loadBar: _jsonData.loadBar ?? true
    property bool loadNotifications: _jsonData.loadNotifications ?? true
    property bool loadOnScreenDisplay: _jsonData.loadOnScreenDisplay ?? true
    property bool loadDialog: _jsonData.loadDialog ?? true
    property bool loadAltTabSwitcher: _jsonData.loadAltTabSwitcher ?? true
    property bool loadPopup: _jsonData.loadPopup ?? true
    property bool loadPolkit: _jsonData.loadPolkit ?? true
    property bool loadLauncher: _jsonData.loadLauncher ?? true
    property bool loadDesktop: _jsonData.loadDesktop ?? true
    property bool loadScreenCapture: _jsonData.loadScreenCapture ?? true
    property bool blurLockscreen: _jsonData.blurLockscreen ?? false
    property bool hideTopBar: _jsonData.hideTopBar ?? false
    property bool forceCompactBar: _jsonData.forceCompactBar ?? false
    property bool doNotDisturb: _jsonData.doNotDisturb ?? false
    property bool nightLightEnabled: _jsonData.nightLightEnabled ?? _jsonData.hyprsunsetEnabled ?? false
    property bool monitorsPowered: _jsonData.monitorsPowered ?? _jsonData.hyprlandDPMS ?? true
    property bool enableShadow: _jsonData.enableShadow ?? true
    property bool enableRounding: _jsonData.enableRounding ?? true
    property bool transparentize: _jsonData.transparentize ?? true
    property bool isPowerSaverEnabled: _jsonData.isPowerSaverEnabled ?? false
    property bool forcePowerSaver: _jsonData.forcePowerSaver ?? false
    property string mainMonitor: _jsonData.mainMonitor || Quickshell.screens[0].name
    property var wallpaperProviderKeys: _jsonData.wallpaperProviderKeys || (_jsonData.wallhavenApiKey ? { "wallhaven": _jsonData.wallhavenApiKey } : ({}))
    property var launcherOverrides: _jsonData.launcherOverrides || []

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
        settingsJson.setData(JSON.stringify(collectData(), null, 2));
    }
}
