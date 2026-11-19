pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.greeter
import qs

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        required property var modelData
        screen: modelData
        color: Theme.colors.bgBase

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:greeter"
        WlrLayershell.keyboardFocus: (!Hyprland.focusedMonitor || screen.name === Hyprland.focusedMonitor.name) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        GreeterContent {}
    }
}
