pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/NiriState.js" as NiriState
import "../lib/AppUtils.js" as AppUtils

Singleton {
    id: root
    property var state: NiriState.empty()
    readonly property var windows: state.windows
    readonly property var workspaces: state.workspaces
    property var outputs: []
    readonly property var focusedWindow: windows.find(w => w.is_focused) || null
    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) || null
    readonly property string focusedOutput: focusedWorkspace?.output || ""
    readonly property var previousFocusedWindowId: state.previousFocusedWindowId
    readonly property bool focusedWorkspaceHasNoWindows: focusedWorkspace !== null && !windows.some(w => w.workspace_id === focusedWorkspace.id)
    property bool connected: false
    property int retryDelay: 1000
    readonly property string helper: Quickshell.shellDir + "/scripts/niri_settings.py"
    property var appearance: ({ shadows: true, transparency: false, rounded: true, bigGaps: false })
    property bool settingsBusy: false
    property bool appearanceChangePending: false
    signal settingsFinished(string kind, bool success, string error)

    Component.onCompleted: {
        if (!Paths.isGreeter) {
            stream.running = true;
            refreshOutputs();
            settingsBusy = true;
            settings.exec(["python3", helper, "get"]);
        }
    }

    Process {
        id: stream
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    root.state = NiriState.reduce(root.state, event);
                    root.connected = true;
                    root.retryDelay = 1000;
                    if (event.WorkspacesChanged) outputDebounce.restart();
                } catch (error) { console.warn("Niri event:", error); }
            }
        }
        onExited: {
            root.connected = false;
            root.state = NiriState.empty();
            root.outputs = [];
            reconnect.restart();
            root.retryDelay = Math.min(root.retryDelay * 2, 30000);
        }
    }
    Timer { id: reconnect; interval: root.retryDelay; onTriggered: stream.running = true }
    Timer { id: outputDebounce; interval: 200; onTriggered: root.refreshOutputs() }
    // niri 26.04 has no output-change event. Also catch mode changes without workspace changes.
    Timer { interval: 5000; repeat: true; running: root.connected; onTriggered: root.refreshOutputs() }
    Process {
        id: outputQuery
        command: ["niri", "msg", "-j", "outputs"]
        property string result: ""
        stdout: StdioCollector { onStreamFinished: outputQuery.result = text }
        onExited: code => {
            if (code !== 0) return;
            try {
                const value = NiriState.normalizeOutputs(JSON.parse(result));
                if (JSON.stringify(value) !== JSON.stringify(root.outputs)) root.outputs = value;
            } catch (error) { console.warn("Niri outputs:", error); }
        }
    }
    Process {
        id: settings
        property string result: ""
        stdout: StdioCollector { onStreamFinished: settings.result = text }
        onExited: code => {
            root.settingsBusy = false;
            try {
                const response = JSON.parse(result);
                if (response.appearance) {
                    root.appearance = response.appearance;
                    GlobalSettings.enableRounding = root.appearance.rounded;
                }
                if (root.appearanceChangePending) {
                    if (code === 0) {
                        GlobalIpc.popup.showInfo("Appearance Settings Saved", "", 1500);
                    } else GlobalIpc.popup.showError("Appearance Settings Failed", response.error || "Unknown error", 6000);
                }
                root.settingsFinished("appearance", code === 0, response.error || "");
            } catch (error) {
                if (root.appearanceChangePending) GlobalIpc.popup.showError("Appearance Settings Failed", "Could not read settings result", 6000);
                root.settingsFinished("appearance", false, "Could not read settings result");
            }
            root.appearanceChangePending = false;
        }
    }
    function refreshOutputs() { if (!outputQuery.running && !Paths.isGreeter) outputQuery.running = true; }
    function getMonitorOfScreen(screen) { return outputs.find(m => m.name === (screen ? screen.name : focusedOutput)) || null; }
    function action(argv) { if (Array.isArray(argv) && argv.length) Quickshell.execDetached(["niri", "msg", "action"].concat(argv)); }
    function focusWindow(id) { if (Number.isSafeInteger(id) && id >= 0) action(["focus-window", "--id", String(id)]); }
    function focusWorkspace(id) {
        if (Number.isSafeInteger(id) && id >= 0 && workspaces.some(w => w.id === id))
            Quickshell.execDetached(["python3", helper, "focus-workspace", String(id)]);
    }
    function focusApp(query) {
        const q = AppUtils.normalizeAppId(query);
        if (!q) return;
        let matches = windows.filter(w => AppUtils.normalizeAppId(w.app_id) === q);
        // Explicit tool-window titles are used by package/update helpers, never substring matches.
        if (!matches.length) matches = windows.filter(w => w.title === String(query).trim());
        const window = matches.find(w => w.is_focused) || matches[0];
        if (window) focusWindow(window.id);
    }
    function spawn(argv) { if (Array.isArray(argv) && argv.length) action(["spawn", "--"].concat(argv)); }
    function setDPMS(value) {
        action([value ? "power-on-monitors" : "power-off-monitors"]);
        GlobalSettings.monitorsPowered = !!value;
    }
    function toggleDPMS() { setDPMS(!GlobalSettings.monitorsPowered); }
    function toggleAppearance(key) {
        if (settingsBusy || !Object.prototype.hasOwnProperty.call(appearance, key)) return;
        settingsBusy = true;
        appearanceChangePending = true;
        settings.exec(["python3", helper, "appearance", key, String(!appearance[key])]);
    }
}
