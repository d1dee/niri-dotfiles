//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_SCALE_FACTOR=1
//@ pragma Env QSG_RHI_BACKEND=vulkan
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=subpixel
//@ pragma IconTheme Papirus-Dark

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs
import qs.lock
import qs.services
import qs.surfaces.bar
import qs.surfaces.osd
import qs.surfaces.popup
import qs.surfaces.polkit
import qs.surfaces.dialog
import qs.surfaces.alttab
import qs.surfaces.capture
import qs.surfaces.desktop
import qs.surfaces.launcher
import qs.surfaces.notifications
import qs.surfaces.screensharepicker

ShellRoot {
    Component.onCompleted: {
        GlobalIpc;
        GlobalShortcuts;
        GlobalCache;
        GlobalStates;
        GlobalSettings;
        GlobalData;

        PowerProfilesService;
        PowerSaverService;
        NotificationService;
        InhibitorService;
        WeatherService;
        CalendarService;
        NetworkService;
        MprisService;
        BrightnessService;
        OnScreenDisplayService;
        ClipboardService;
        ProcessesService;
        LauncherService;
        TranslateService;
        FilesService;
        HomeService;
        UpdateService;
        TasksService;
        ColorPickerService;
        AltTabService;
        CommandsService;
        WallpaperService;
        WallhavenService;
        MonitorService;
        HyprlandService;
        LockService;
        ScreenShareService;

        if (GlobalData.wallpaperPath === "")
            Quickshell.execDetached([Paths.selectWallpaperScript, "--path", Paths.defaultWallpaper]);

        Quickshell.execDetached(["sh", "-c", `for p in '[n]otify-send --app-name=Updates' '[p]w-dump -m'; do pkill --older 120 -f "$p" 2>/dev/null; done`]);
    }

    Binding {
        target: GlobalIpc
        property: "launcher"
        value: launcher.item
    }
    Binding {
        target: GlobalIpc
        property: "dialog"
        value: dialog.item
    }
    Binding {
        target: GlobalIpc
        property: "popup"
        value: popup.item
    }
    Binding {
        target: GlobalIpc
        property: "capture"
        value: capture.item
    }
    Binding {
        target: GlobalIpc
        property: "screensharepicker"
        value: screensharepicker.item
    }

    LazyLoader {
        id: bar
        active: GlobalSettings.loadBar
        component: Bar {}
    }

    LazyLoader {
        id: notifications
        active: GlobalSettings.loadNotifications
        component: NotificationPopups {}
    }

    LazyLoader {
        id: osd
        active: GlobalSettings.loadOnScreenDisplay
        component: OnScreenDisplay {}
    }

    LazyLoader {
        id: popup
        active: GlobalSettings.loadPopup
        component: Popup {}
    }

    LazyLoader {
        id: launcher
        active: GlobalSettings.loadLauncher
        component: Launcher {}
    }

    LazyLoader {
        id: monitorLabels
        active: GlobalSettings.loadLauncher
        component: MonitorLabelsOverlay {}
    }

    LazyLoader {
        id: polkit
        active: GlobalSettings.loadPolkit
        component: Polkit {}
    }

    LazyLoader {
        id: dialog
        active: GlobalSettings.loadDialog
        component: Dialog {}
    }

    LazyLoader {
        id: capture
        active: GlobalSettings.loadScreenCapture
        component: ScreenCapture {}
    }

    LazyLoader {
        id: screensharepicker
        active: GlobalCache.loadScreenSharePicker
        component: ScreenSharePicker {}
    }

    LazyLoader {
        id: altTabSwitcher
        active: GlobalSettings.loadAltTabSwitcher && GlobalStates.showAltTabSwitcher
        component: AltTabSwitcher {}
    }

    LazyLoader {
        id: lock
        active: GlobalCache.loadLockScreen
        component: LockContent {}
    }

    LazyLoader {
        id: desktop
        active: GlobalSettings.loadDesktop
        component: Desktop {}
    }
}
