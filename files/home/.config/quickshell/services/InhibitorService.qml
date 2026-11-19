pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

Singleton {
    id: root

    readonly property string materialSymbol: inhibit ? "moon_stars" : "bedtime"
    readonly property bool inhibit: !GlobalSettings.monitorsPowered || _inhibit
    readonly property bool toggleInhibitEnabled: GlobalSettings.monitorsPowered
    property alias _inhibit: idleInhibitor.enabled

    // Timed Inhibition
    property int selectedDuration: 0 // in seconds, 0 = Infinite
    property int remainingTime: 0    // in seconds
    property real _endTime: 0        // timestamp

    function toggleInhibit() {
        idleInhibitor.enabled = !idleInhibitor.enabled;
        if (root.inhibit) {
            if (root.selectedDuration > 0) {
                root._endTime = Date.now() + (root.remainingTime * 1000);
            }
        }
        root.persist();
    }

    function updateDuration(secs: int) {
        root.selectedDuration = secs;
        root.remainingTime = secs;
        if (root.inhibit && secs > 0) {
            root._endTime = Date.now() + (secs * 1000);
        }
        root.persist();
    }

    function persist() {
        GlobalCache.inhibitorState = JSON.stringify({
            inhibit: root.inhibit,
            selectedDuration: root.selectedDuration,
            remainingTime: root.remainingTime,
            endTime: root._endTime
        });
    }

    Component.onCompleted: {
        const stateStr = GlobalCache.inhibitorState;
        if (stateStr) {
            try {
                const s = JSON.parse(stateStr);
                root.selectedDuration = s.selectedDuration ?? 0;
                root.remainingTime = s.remainingTime ?? 0;
                root._inhibit = s.inhibit ?? false;
                root._endTime = s.endTime ?? 0;

                if (root.inhibit && root.selectedDuration > 0) {
                    const now = Date.now();
                    if (root._endTime > now) {
                        root.remainingTime = Math.floor((root._endTime - now) / 1000);
                    } else {
                        root._inhibit = false;
                        root.remainingTime = root.selectedDuration;
                    }
                }
            } catch (_) {}
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.inhibit && root.selectedDuration > 0

        onTriggered: {
            const now = Date.now();
            const diff = root._endTime - now;

            if (diff <= 0) {
                root._inhibit = false;
                root.remainingTime = root.selectedDuration;
                root.persist();
            } else {
                root.remainingTime = Math.floor(diff / 1000);
            }
        }
    }

    IdleInhibitor {
        id: idleInhibitor
        enabled: false
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:inhibitor"
            mask: Region {
                item: null
            }
        }
    }
}
