pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import qs.services
import qs

Singleton {
    id: root

    property bool locked: false
    property bool showUI: false
    property bool hasFailed: false
    property bool isLocking: false
    property bool lockInput: false
    property bool isAuthenticating: false
    property bool navigateBeforeLock: true
    property int lastTotalWindows: 0
    property var lastSpecialWorkspace: false
    property string passwordInput: ""
    onIsLockingChanged: GlobalStates.isLocking = root.isLocking

    function lock(navigateBeforeLock) {
        if (locked || isLocking)
            return;
        root.isLocking = true;
        root.hasFailed = false;
        root.lockInput = false;
        root.passwordInput = "";
        root.navigateBeforeLock = navigateBeforeLock;
        root.lastSpecialWorkspace = HyprlandService.currentSpecialWorkspace || false;
        Hyprland.dispatch(`hl.dsp.focus({ monitor = '${GlobalSettings.mainMonitor}' })`);
        if (root.navigateBeforeLock) {
            root.lastTotalWindows = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.toplevels.values.length : 0;
            if (root.lastSpecialWorkspace !== false)
                Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${root.lastSpecialWorkspace.replace("special:", "")}")`);
            Hyprland.dispatch("require('hyprland.lua.utils.workspaces'):go('new')");
        }
        shortcutInhibitor.enabled = true;
        if (Hyprland.monitors.values.length === 1) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({cursor = {invisible = true} })"]);
        } else {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({cursor = {inactive_timeout = 1} })"]);
        }
        GlobalCache.loadLockScreen = true;
        lockTimer.start();
    }

    function unlock() {
        // IPC/logind unlock requests are not proof of authentication.
        if (!locked || !showUI || pamContext.active)
            return;
        if (!pamContext.start())
            root.hasFailed = true;
    }

    function submit() {
        if (!locked || !showUI || lockInput || isAuthenticating)
            return;
        if (!pamContext.active) {
            root.unlock();
            return;
        }
        if (!pamContext.responseRequired)
            return;

        hasFailed = false;
        isAuthenticating = true;
        pamContext.respond(passwordInput);
    }

    ShortcutInhibitor {
        id: shortcutInhibitor
        enabled: false
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:shortcutinhibitor"
            WlrLayershell.keyboardFocus: shortcutInhibitor.enabled ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region {
                item: null
            }
        }
    }

    // Delay locking slightly to let the lock screen load
    Timer {
        id: lockTimer
        interval: 200
        triggeredOnStart: false
        onTriggered: {
            root.locked = true;
            root.showUI = true;
            root.unlock();
            shortcutInhibitor.enabled = false;
            root.isLocking = false;
        }
    }

    // Delay unlocking slightly to let the hide animation play
    Timer {
        id: unlockTimer
        interval: 400
        onTriggered: {
            root.locked = false;
            GlobalCache.loadLockScreen = false;
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({cursor = {invisible = false, inactive_timeout = 5} })"]);
            if (root.navigateBeforeLock) {
                if (root.lastSpecialWorkspace !== false)
                    Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${root.lastSpecialWorkspace.replace("special:", "")}")`);
                if (root.lastTotalWindows !== 0) {
                    Hyprland.dispatch("require('hyprland.lua.utils.workspaces'):go('back')");
                    root.lastTotalWindows = 0;
                }
            }
            root.navigateBeforeLock = true;
        }
    }

    Timer {
        interval: 3000
        running: root.hasFailed
        onTriggered: root.hasFailed = false
    }

    PamContext {
        id: pamContext
        config: "bnsplit-lock"

        onPamMessage: {
            if (messageIsError)
                root.hasFailed = true;
            if (responseRequired)
                root.isAuthenticating = false;
        }

        onCompleted: result => {
            root.isAuthenticating = false;
            root.passwordInput = "";
            if (!root.locked || !root.showUI)
                return;
            if (result === PamResult.Success) {
                root.hasFailed = false;
                root.showUI = false;
                unlockTimer.start();
            } else {
                root.hasFailed = true;
                // Retry rejected credentials, but do not loop on a broken PAM service.
                if (result === PamResult.Failed)
                    Qt.callLater(() => root.unlock());
            }
        }
    }
}
