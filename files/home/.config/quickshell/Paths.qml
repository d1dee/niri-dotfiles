pragma Singleton
pragma ComponentBehavior: Bound

import Qt.labs.platform
import QtQuick
import Quickshell
import "./lib/FileUtils.js" as FileUtils

Singleton {
    readonly property bool isGreeter: Quickshell.env("BNSPLIT_GREETER") === "1"
    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]

    readonly property string local: home + "/.local"
    readonly property string cache: home + "/.cache"

    readonly property string hypr: config + "/hypr"
    readonly property string hlDir: hypr + "/hyprland"
    readonly property string hlRulesJson: hlDir + "/json/rules.json"
    readonly property string hlMonitorsJson: hlDir + "/json/monitors.json"
    readonly property string hlDecorationJson: hlDir + "/json/decoration.json"
    readonly property string hlGeneralJson: hlDir + "/json/general.json"
    readonly property string hlPowerSaverJson: hlDir + "/json/powersaver.json"

    readonly property string state: local + "/state/bnsplit"

    readonly property string screenshotDir: pictures + "/Screenshots"

    readonly property string bnclipDecodeTempDir: "/tmp/bnsplit/bnclip"
    readonly property string screenshotTempDir: "/tmp/bnsplit/screenshots"
    readonly property string colorPickerTempDir: "/tmp/bnsplit/colorpicker"

    readonly property string wallpaperTmp: cache + "/bnsplit/wallpaper-tmp"
    readonly property string wallpaperWebp: cache + "/bnsplit/wallpaper-webp"
    readonly property string defaultWallpaper: Quickshell.shellDir + "/assets/default-wallpaper"
    readonly property string wallpapersJsonFile: state + "/wallpapers.json"
    readonly property string wallpaperSelectedColorIndexFile: state + "/color-number"
    readonly property string wallpaperDir: pictures + "/Wallpapers"
    readonly property string greeterSettingsJsonFile: "/var/lib/greetd/bnsplit/greeter-settings.json"
    readonly property string qalcHistory: state + "/qalc.history"
    readonly property string weatherFile: state + "/weather.json"
    readonly property string mprisFile: state + "/mpris-players.json"
    readonly property string updatesJsonFile: state + "/updates.json"
    readonly property string todoistTasksFile: cache + "/bnsplit/todoist/tasks.json"
    readonly property string todoistStatusFile: cache + "/bnsplit/todoist/status.json"

    readonly property string wallhavenThumbnailsDir: cache + "/bnsplit/wallhaven-thumbnails"
    readonly property string wallhavenTempDir: "/tmp/bnsplit/wallhaven"
    readonly property string unsplashThumbnailsDir: cache + "/bnsplit/unsplash-thumbnails"
    readonly property string unsplashTempDir: "/tmp/bnsplit/unsplash"

    readonly property string wallpaperColorsFile: cache + "/bnchroma/colors"

    readonly property string scripts: Quickshell.shellDir + "/scripts"
    readonly property string screenRecordScript: scripts + "/screen_record.sh"
    readonly property string rectDetectorScript: scripts + "/rect_detector.py"
    readonly property string mprisPlayersProcessorScript: scripts + "/mpris_players_processor.sh"
    readonly property string weatherFetcherScript: scripts + "/weather_fetcher.sh"
    readonly property string calendarFetcherScript: scripts + "/calendar_fetcher.py"
    readonly property string processesFetcherScript: scripts + "/processes_fetcher.py"
    readonly property string filesFetcherScript: scripts + "/files_fetcher.py"
    readonly property string commandsFetcherScript: scripts + "/commands_fetcher.py"
    readonly property string wallpaperFetcherScript: scripts + "/wallpaper_fetcher.py"
    readonly property string greeterFetcherScript: scripts + "/greeter_fetcher.py"
    readonly property string systemUpdateScript: scripts + "/system_update.sh"
    readonly property string desktopWidgetScript: scripts + "/desktop_widget_fetcher.py"
    readonly property string lensScript: scripts + "/lens.sh"
    readonly property string selectWallpaperScript: (Quickshell.env("BN_SCRIPTS") || (home + "/.local/share/bnsplit/scripts")) + "/select-wallpaper"

    readonly property string store: Quickshell.shellDir + "/store"
    readonly property string settingsJsonFile: store + "/settings.json"
    readonly property string dataJsonFile: store + "/data.json"
    readonly property string colorsJsonFile: store + "/colors.json"

    readonly property string qsCache: Quickshell.cacheDir
    readonly property string cacheJsonFile: qsCache + "/cache.json"

    readonly property string dotconfDir: Quickshell.shellDir + "/assets/config"

    Component.onCompleted: {
        if (!isGreeter) {
            const trim = str => FileUtils.trimFileProtocol(str);

            Quickshell.execDetached(["touch", `${trim(settingsJsonFile)}`]);
            Quickshell.execDetached(["touch", `${trim(dataJsonFile)}`]);
            Quickshell.execDetached(["touch", `${trim(colorsJsonFile)}`]);
            Quickshell.execDetached(["touch", `${trim(cacheJsonFile)}`]);
            Quickshell.execDetached(["touch", `${trim(qalcHistory)}`]);

            Quickshell.execDetached(["mkdir", "-p", `${trim(screenshotTempDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(bnclipDecodeTempDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(colorPickerTempDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(state)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(dotconfDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(cache)}/bnsplit/todoist`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(wallhavenThumbnailsDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(wallhavenTempDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(unsplashThumbnailsDir)}`]);
            Quickshell.execDetached(["mkdir", "-p", `${trim(unsplashTempDir)}`]);
        }
    }
}
