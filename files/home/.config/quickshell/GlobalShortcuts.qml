pragma ComponentBehavior: Bound
pragma Singleton

import Quickshell
import qs

Singleton {
    function isLocked(): bool {
        return GlobalCache.loadLockScreen;
    }

    function toggleBarModule(name: string): void {
        if (isLocked())
            return;
        const modules = ["resources", "mprisPlayers", "dateTime", "weather", "controlCenter", "battery"];
        if (!modules.includes(name))
            return;
        GlobalStates.expandedBarModule = GlobalStates.expandedBarModule === name ? "" : name;
    }
}
