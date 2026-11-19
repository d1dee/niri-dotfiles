pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

Singleton {
    id: root
    readonly property int clockWidgetWidth: 300
    readonly property int clockWidgetHeight: 125
    readonly property var mainScreen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) ?? Quickshell.screens[0] ?? null
    readonly property var mainMonitor: {
        const output = NiriService.getMonitorOfScreen(mainScreen);
        return mainScreen && output?.name === mainScreen.name ? output : null;
    }
    // The helper and widget both use output-local logical pixels, including rotation.
    readonly property size placementSize: Qt.size(mainMonitor?.logical?.width ?? mainScreen?.width ?? 0, mainMonitor?.logical?.height ?? mainScreen?.height ?? 0)
    onPlacementSizeChanged: Qt.callLater(root.refresh)
    onMainMonitorChanged: Qt.callLater(root.refresh)

    property string wallpaperContentHash: ""
    property bool fetchPending: false

    function selectWallpaper(wallpaperPath: string, isTemporaryWallpaper: bool, contentHash: string) {
        if (GlobalData.wallpaperWebpPath !== Paths.wallpaperWebp)
            GlobalData.wallpaperWebpPath = Paths.wallpaperWebp;
        if (!isTemporaryWallpaper && wallpaperPath === GlobalData.wallpaperPath)
            return;
        GlobalData.wallpaperPath = wallpaperPath;
        root.wallpaperContentHash = contentHash ?? "";
        if (contentHash !== undefined && contentHash !== "")
            GlobalData.wallpaperContentHash = contentHash;
        root.refresh();
    }

    function refresh() {
        if (!root.mainMonitor || placementSize.width <= 0 || placementSize.height <= 0)
            return;
        if (dataFetcher.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        const command = ["python3", Paths.desktopWidgetScript, GlobalData.wallpaperPath,
            "--screen-width", String(Math.round(placementSize.width)),
            "--screen-height", String(Math.round(placementSize.height)),
            "--widget-width", String(clockWidgetWidth),
            "--widget-height", String(clockWidgetHeight)];
        if (root.wallpaperContentHash !== "")
            command.push("--content-hash", root.wallpaperContentHash);
        dataFetcher.exec(command);
    }

    Process {
        id: dataFetcher
        onExited: {
            if (root.fetchPending)
                Qt.callLater(root.refresh);
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (!root.mainMonitor || root.fetchPending)
                        return;
                    const data = JSON.parse(text);
                    GlobalData.desktopWidgetData = data;
                } catch (e) {}
            }
        }
    }
}
