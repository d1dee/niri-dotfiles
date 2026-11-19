pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

Singleton {
    id: root
    readonly property var monitors: NiriService.outputs
    property bool dataChanged: false
    property bool showConfirmPopup: false
    property int confirmTimer: 10
    readonly property int confirmTimerDuration: 10
    property string pendingToken: ""
    readonly property bool busy: applyProcess.running || confirmProcess.running

    Connections {
        target: NiriService
        function onOutputsChanged() { root.dataChanged = !root.dataChanged; }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.showConfirmPopup
        onTriggered: {
            root.confirmTimer--;
            if (root.confirmTimer <= 0) root.revertChanges();
        }
    }
    Process {
        id: applyProcess
        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line);
                    if (result.error) {
                        GlobalIpc.popup.showError("Display Settings Failed", result.error, 6000);
                    } else if (result.status === "applied") {
                        root.pendingToken = result.token;
                        root.confirmTimer = root.confirmTimerDuration;
                        root.showConfirmPopup = true;
                    } else if (result.status === "reverted") {
                        root.showConfirmPopup = false;
                        root.pendingToken = "";
                        GlobalIpc.popup.showInfo("Display Settings Reverted", "", 2000);
                    }
                    NiriService.refreshOutputs();
                } catch (error) { console.warn("Display settings result:", error); }
            }
        }
    }
    Process {
        id: confirmProcess
        property string result: ""
        stdout: StdioCollector { onStreamFinished: confirmProcess.result = text }
        onExited: code => {
            if (code === 0) {
                root.showConfirmPopup = false;
                root.pendingToken = "";
                GlobalIpc.popup.showInfo("Display Settings", "Changes " + (JSON.parse(result).status || "updated"), 2000);
            } else {
                root.showConfirmPopup = false;
                root.pendingToken = "";
                GlobalIpc.popup.showError("Display Settings Failed", result, 6000);
            }
            NiriService.refreshOutputs();
        }
    }
    function fetchMonitors() { NiriService.refreshOutputs(); }
    function setMonitors(configs, changedNames) {
        if (busy || showConfirmPopup || !changedNames.length) return;
        applyProcess.exec(["python3", NiriService.helper, "outputs", JSON.stringify(configs), JSON.stringify(changedNames)]);
    }
    function revertChanges() {
        if (pendingToken && !confirmProcess.running)
            confirmProcess.exec(["python3", NiriService.helper, "revert", pendingToken]);
    }
    function keepChanges() {
        if (pendingToken && !confirmProcess.running)
            confirmProcess.exec(["python3", NiriService.helper, "keep", pendingToken]);
    }
}
