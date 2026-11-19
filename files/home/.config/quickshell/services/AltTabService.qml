pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import "../lib/AppUtils.js" as AppUtils

Singleton {
    id: root

    property var flattenedToplevels: []
    property int selectedIndex: 0

    readonly property bool isVisible: GlobalStates.showAltTabSwitcher

    // Window paging logic
    readonly property int itemsPerRow: 3
    readonly property int rowsPerPage: 3
    readonly property int itemsPerPage: itemsPerRow * rowsPerPage

    property var windowPages: {
        let pages = [];
        let filtered = flattenedToplevels;

        for (let i = 0; i < filtered.length; i += itemsPerPage) {
            let page = [];
            for (let j = 0; j < rowsPerPage; j++) {
                let row = [];
                let start = i + j * itemsPerRow;
                for (let k = 0; k < itemsPerRow && start + k < filtered.length; k++) {
                    row.push(filtered[start + k]);
                }
                if (row.length > 0)
                    page.push(row);
            }
            if (page.length > 0)
                pages.push(page);
        }
        return pages;
    }

    function updateToplevels() {
        let filtered = NiriService.windows.filter(t => AppUtils.normalizeAppId(t.app_id) !== "quickshell");
        let active = NiriService.focusedWindow;
        if (active) {
            let index = filtered.findIndex(t => t.id === active.id);
            if (index !== -1) {
                let t = filtered.splice(index, 1)[0];
                filtered.unshift(t);
            }
        }

        const previousId = NiriService.previousFocusedWindowId;
        if (previousId !== null && filtered.length > 1) {
            let lastIndex = filtered.findIndex(t => t.id === previousId);
            // Only move it if it's not already at index 1 or 0
            if (lastIndex > 1) {
                let t = filtered.splice(lastIndex, 1)[0];
                filtered.splice(1, 0, t);
            }
        }

        flattenedToplevels = filtered;
    }

    // Keep selection stable across title updates, closes and new windows while open.
    function syncWindows() {
        const selectedId = flattenedToplevels[selectedIndex]?.id;
        const windows = NiriService.windows.filter(t => AppUtils.normalizeAppId(t.app_id) !== "quickshell");
        const ordered = flattenedToplevels.map(t => windows.find(w => w.id === t.id)).filter(Boolean);
        const ids = new Set(ordered.map(t => t.id));
        flattenedToplevels = ordered.concat(windows.filter(t => !ids.has(t.id)));
        const index = flattenedToplevels.findIndex(t => t.id === selectedId);
        selectedIndex = index >= 0 ? index : Math.max(0, Math.min(selectedIndex, flattenedToplevels.length - 1));
        if (flattenedToplevels.length === 0)
            close();
    }

    Connections {
        target: NiriService
        function onWindowsChanged() {
            if (root.isVisible)
                root.syncWindows();
        }
    }

    function switchNext() {
        if (!GlobalStates.showAltTabSwitcher) {
            updateToplevels();
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = flattenedToplevels.length > 1 ? 1 : 0;
            GlobalStates.showAltTabSwitcher = true;
        } else {
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = (selectedIndex + 1) % flattenedToplevels.length;
        }
    }

    function switchPrevious() {
        if (!GlobalStates.showAltTabSwitcher) {
            updateToplevels();
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = flattenedToplevels.length - 1;
            GlobalStates.showAltTabSwitcher = true;
        } else {
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = (selectedIndex - 1 + flattenedToplevels.length) % flattenedToplevels.length;
        }
    }

    function activateSelected() {
        if (GlobalStates.showAltTabSwitcher) {
            let toplevel = flattenedToplevels[selectedIndex];
            if (toplevel) {
                NiriService.focusWindow(toplevel.id);
            }
        }
        close();
    }

    function selectAndActivate(index) {
        selectedIndex = index;
        activateSelected();
    }

    function close() {
        GlobalStates.showAltTabSwitcher = false;
    }

    function getToplevelFlatIndex(toplevel) {
        return flattenedToplevels.findIndex(t => t.id === toplevel.id);
    }
}
