pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services

Singleton {
    id: root

    Component.onCompleted: root.applyPowerSaverMode(GlobalSettings.forcePowerSaver || PowerProfiles.profile === PowerProfile.PowerSaver)

    function applyPowerSaverMode(enabled) {
        GlobalSettings.isPowerSaverEnabled = enabled;
    }

    Connections {
        target: GlobalSettings
        function onForcePowerSaverChanged() {
            root.applyPowerSaverMode(GlobalSettings.forcePowerSaver || PowerProfiles.profile === PowerProfile.PowerSaver);
        }
    }

    Connections {
        target: PowerProfiles
        enabled: !GlobalSettings.forcePowerSaver
        function onProfileChanged() {
            root.applyPowerSaverMode(PowerProfiles.profile === PowerProfile.PowerSaver);
        }
    }
}
