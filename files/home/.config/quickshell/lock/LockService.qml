pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs

Singleton {
    id: root

    property bool locked: false
    // Updated by LockContent from compositor acknowledgement, not the request.
    property bool acquired: false
    property bool showUI: false
    property bool hasFailed: false
    property bool isLocking: false
    property bool lockInput: false
    property bool isAuthenticating: false
    property string passwordInput: ""
    onIsLockingChanged: GlobalStates.isLocking = root.isLocking

    function lock() {
        if (locked || isLocking)
            return;
        root.isLocking = true;
        root.hasFailed = false;
        root.lockInput = false;
        root.passwordInput = "";
        root.locked = true;
        GlobalCache.loadLockScreen = true;
    }

    function unlock() {
        // IPC/logind unlock requests are not proof of authentication.
        if (!locked || !acquired || !showUI || pamContext.active)
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

    onAcquiredChanged: {
        if (acquired) {
            root.showUI = true;
            root.unlock();
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
