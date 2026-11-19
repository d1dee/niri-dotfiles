pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components

BasePage {
    id: root
    pageIcon: "keyboard"
    pageIconType: "symbol"
    pageName: "Keybinds"
    showSearchbar: false
    enableSearchbar: false
    showSearchbarOverlay: false

    function primaryAction() {
        GlobalStates.showLauncher = false;
        NiriService.action(["show-hotkey-overlay"]);
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        StyledText {
            text: "niri Keyboard Shortcuts"
            font.pixelSize: Theme.fontPixelSizes.large
            Layout.alignment: Qt.AlignHCenter
        }
        StyledText {
            text: "View the compositor's native shortcut overlay, including configured hotkey descriptions."
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 480
            horizontalAlignment: Text.AlignHCenter
        }
        StyledButton {
            text: "Show Shortcuts"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.primaryAction()
        }
    }
}
