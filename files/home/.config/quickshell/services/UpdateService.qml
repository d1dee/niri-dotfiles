pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/FileUtils.js" as FileUtils

Singleton {
    id: root
    readonly property string materialSymbol: "deployed_code_update"

    property int updateCount: 0
    property var updatesList: []
    readonly property bool dbLock: false
    property alias checking: checkerProcess.running

    signal fileUpdated

    // Helpers
    function _sortByName(list) {
        return list.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    // Kept for the existing UI; DNF manages its own transaction locks.
    function removeDbLock() {}

    FileView {
        id: updatesJson
        path: FileUtils.trimFileProtocol(Paths.updatesJsonFile)
        watchChanges: false
        blockLoading: true
        onFileChanged: {
            this.reload();
            root._loadFromJson();
            root.fileUpdated();
        }
    }

    function _loadFromJson() {
        const text = updatesJson.text();
        if (!text) {
            root.updatesList = [];
            root.updateCount = 0;
            return;
        }
        try {
            const data = JSON.parse(text);
            root.updatesList = root._sortByName(data.updates || []);
            root.updateCount = root.updatesList.length;
        } catch (e) {}
    }

    // Update Checker
    Process {
        id: checkerProcess
        property var accumulated: []
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^(\S+)\s+(\S+)$/);
                if (match) {
                    checkerProcess.accumulated.push({
                        name: match[1],
                        currentVersion: "",
                        newVersion: match[2]
                    });
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root._finalizeParsed(checkerProcess.accumulated);
            checkerProcess.accumulated = [];
        }
    }

    Timer {
        id: periodicTimer
        interval: 33 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root._timedCheck()
    }

    function _timedCheck() {
        if (Date.now() - GlobalData.lastUpdateCheck >= 30 * 60 * 1000)
            refresh(true);
    }

    function refresh(sync = false) {
        if (checkerProcess.running)
            return;
        checkerProcess.accumulated = [];
        const command = ["dnf", "--quiet"];
        if (sync)
            command.push("--refresh");
        checkerProcess.exec(command.concat(["repoquery", "--upgrades", "--latest-limit=1", "--queryformat", "%{name} %{evr}"]));
    }

    function _finalizeParsed(parsed) {
        const prevCount = root.updateCount;

        root.updatesList = root._sortByName(parsed);
        root.updateCount = root.updatesList.length;
        GlobalData.lastUpdateCheck = Date.now();

        updatesJson.setText(JSON.stringify({
            updates: root.updatesList,
            timestamp: Date.now()
        }, null, 2));

        if (root.updateCount > 0 && root.updateCount > prevCount)
            root._sendNotification();
    }

    // Notification
    function _sendNotification() {
        if (!notificationProcess.running)
            notificationProcess.exec(["notify-send", "--app-name=Updates", "--icon=system-software-update", "--urgency=normal", "--wait", "--action=update=Update Now", "Updates Available: (" + root.updateCount + ")", "New updates are available."]);
    }

    Process {
        id: notificationProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "update")
                    root._launchUpdate([]);
            }
        }
    }

    // Launcher
    function updateAll() {
        _launchUpdate([]);
    }

    function updateSelected(packages) {
        _launchUpdate(packages && packages.length > 0 ? packages : []);
    }

    function _launchUpdate(packages) {
        NiriService.spawn(["kitty", "--class=float", "--title=quickshell-system-update", "bash", FileUtils.trimFileProtocol(Paths.systemUpdateScript), ...packages]);
    }

    Component.onCompleted: {
        updatesJson.reload();
        root._loadFromJson();
        _timedCheck();
    }
}
