pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs

Singleton {
    id: root

    property var users: []
    property var sessions: []
    property string echoResponse: ""
    property bool isAuthenticating: false
    property bool authenticationHasFailed: false
    property bool awaitingResponse: false
    property bool responseEcho: false

    property string _pendingPassword: ""
    property bool _hasPendingPassword: false
    property string _pendingSessionType: ""
    property var _pendingSessionCmd: []
    property string _pendingSessionDesktop: ""
    property var _pendingDesktopNames: []

    Component.onCompleted: {
        fetchDiscoveryData();
    }

    function fetchDiscoveryData() {
        discoveryProcess.running = true;
    }

    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function restart() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function restartToBios() {
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }

    function powerOff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    Timer {
        id: authenticationHasFailedTimer
        interval: 5000
        running: root.authenticationHasFailed && root.echoResponse === ""
        onTriggered: root.authenticationHasFailed = false
    }

    Process {
        id: discoveryProcess
        command: ["python3", Paths.greeterFetcherScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.users = (data.users || []).map(u => Object.assign({
                            text: u.name
                        }, u));
                    root.sessions = (data.sessions || []).map(s => Object.assign({
                            text: s.name
                        }, s));
                } catch (e) {
                    console.error("Failed to parse greeter discovery data:", e);
                }
            }
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error || !responseRequired) {
                root.echoResponse = message;
            }

            if (responseRequired && root._hasPendingPassword && !echoResponse) {
                Greetd.respond(root._pendingPassword);
                root._pendingPassword = "";
                root._hasPendingPassword = false;
            } else if (responseRequired) {
                root._pendingPassword = "";
                root._hasPendingPassword = false;
                root.awaitingResponse = true;
                root.responseEcho = echoResponse;
                root.echoResponse = message;
                root.isAuthenticating = false;
            }
        }

        function onAuthFailure(message) {
            root.isAuthenticating = false;
            root.awaitingResponse = false;
            root.authenticationHasFailed = true;
            root._pendingPassword = "";
            root._hasPendingPassword = false;
            root.echoResponse = message;
        }

        function onError(error) {
            root.isAuthenticating = false;
            root.awaitingResponse = false;
            root.authenticationHasFailed = true;
            root._pendingPassword = "";
            root._hasPendingPassword = false;
            root.echoResponse = error;
        }

        function onReadyToLaunch() {
            root.isAuthenticating = false;
            root.awaitingResponse = false;
            root._pendingPassword = "";
            root._hasPendingPassword = false;
            let env = [`XDG_SESSION_TYPE=${root._pendingSessionType}`];
            if (root._pendingSessionDesktop !== "") {
                env.push(`XDG_SESSION_DESKTOP=${root._pendingSessionDesktop}`);
                env.push(`DESKTOP_SESSION=${root._pendingSessionDesktop}`);
            }
            let currentDesktop = root._pendingDesktopNames.length > 0
                ? root._pendingDesktopNames.join(":")
                : root._pendingSessionDesktop;
            if (currentDesktop !== "")
                env.push(`XDG_CURRENT_DESKTOP=${currentDesktop}`);
            Greetd.launch(root._pendingSessionCmd, env);
        }
    }

    function login(username, password, sessionCmd, sessionType, sessionDesktop, desktopNames) {
        if (root.awaitingResponse) {
            root.awaitingResponse = false;
            root.isAuthenticating = true;
            Greetd.respond(password);
            return;
        }
        if (root.isAuthenticating)
            return;
        if (!Greetd.available || !username || !sessionCmd || sessionCmd.length === 0) {
            root.echoResponse = "Select a user and session; login must run under greetd.";
            root.authenticationHasFailed = true;
            return;
        }
        root._pendingPassword = password;
        root._hasPendingPassword = true;
        root._pendingSessionType = sessionType;
        root._pendingSessionCmd = typeof sessionCmd === "string" ? ["/bin/sh", "-c", sessionCmd] : sessionCmd;
        root._pendingSessionDesktop = sessionDesktop || "";
        root._pendingDesktopNames = desktopNames || [];
        root.isAuthenticating = true;
        root.authenticationHasFailed = false;
        root.responseEcho = false;
        root.echoResponse = "";
        Greetd.createSession(username);
    }
}
