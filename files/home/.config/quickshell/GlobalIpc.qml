pragma Singleton

import Quickshell
import Quickshell.Io
import qs.services
import qs.lock
import qs

Singleton {
    id: root

    property var launcher
    property var dialog
    property var popup
    property var capture

    IpcHandler {
        target: "settings"

        function get(key: string): string {
            return GlobalSettings[key];
        }
        function set(key: string, val: string): void {
            try {
                GlobalSettings[key] = JSON.parse(val);
            } catch (e) {
                GlobalSettings[key] = val;
            }
        }
        function toggle(key: string): void {
            if (typeof GlobalSettings[key] === "boolean") {
                GlobalSettings[key] = !GlobalSettings[key];
            }
        }
    }

    IpcHandler {
        target: "data"

        function get(key: string): string {
            return GlobalData[key];
        }
        function set(key: string, val: string): void {
            try {
                GlobalData[key] = JSON.parse(val);
            } catch (e) {
                GlobalData[key] = val;
            }
        }
    }

    IpcHandler {
        target: "cache"
        function get(key: string): string {
            return GlobalCache[key];
        }
        function set(key: string, val: string): void {
            try {
                GlobalCache[key] = JSON.parse(val);
            } catch (e) {
                GlobalCache[key] = val;
            }
        }
    }

    IpcHandler {
        target: "state"

        function get(key: string): string {
            return GlobalStates[key];
        }
        function set(key: string, val: string): void {
            try {
                GlobalStates[key] = JSON.parse(val);
            } catch (e) {
                GlobalStates[key] = val;
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (!GlobalShortcuts.isLocked() && root.launcher)
                root.launcher.toggle();
        }
        function launch(mode: string): void {
            if (!GlobalShortcuts.isLocked() && root.launcher)
                root.launcher.launch(mode);
        }
        function execute(id: string): void {
            if (!GlobalShortcuts.isLocked() && root.launcher)
                root.launcher.execute(id);
        }
    }

    IpcHandler {
        target: "bar"

        function toggleModule(name: string): void {
            GlobalShortcuts.toggleBarModule(name);
        }
        function openModule(name: string): void {
            if (GlobalShortcuts.isLocked())
                return;
            const modules = ["resources", "mprisPlayers", "dateTime", "weather", "controlCenter", "battery"];
            if (!modules.includes(name))
                return;
            if (name !== GlobalStates.expandedBarModule)
                GlobalStates.expandedBarModule = name;
        }
        function closeModule(): void {
            GlobalStates.expandedBarModule = "";
        }
    }

    IpcHandler {
        target: "dialog"

        function showConfirm(title: string, description: string, cancelText: string, proceedText: string, cancelCommand: string, proceedCommand: string): void {
            if (root.dialog)
                root.dialog.showConfirm(title, description, cancelText, proceedText, cancelCommand, proceedCommand);
        }
        function showInfo(title: string, message: string, okText: string, okCommand: string): void {
            if (root.dialog)
                root.dialog.showInfo(title, message, okText, okCommand);
        }
    }

    IpcHandler {
        target: "popup"

        function showError(title: string, message: string, duration: int): void {
            if (root.popup)
                root.popup.showError(title, message, duration);
        }
        function showInfo(title: string, message: string, duration: int): void {
            if (root.popup)
                root.popup.showInfo(title, message, duration);
        }
        function showSuccess(title: string, message: string, duration: int): void {
            if (root.popup)
                root.popup.showSuccess(title, message, duration);
        }
        function showProgress(title: string, message: string): int {
            if (root.popup)
                return root.popup.showProgress(title, message);
            return -1;
        }
        function setProgress(uid: int, value: real): void {
            if (root.popup)
                root.popup.setProgress(uid, value);
        }
        function completeProgress(uid: int, ok: bool, title: string, message: string, duration: int): void {
            if (root.popup)
                root.popup.completeProgress(uid, ok, title, message, duration);
        }
        function dismiss(uid: int): void {
            if (root.popup)
                root.popup.dismiss(uid);
        }
    }

    IpcHandler {
        target: "screencapture"

        function region(): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.startRegionCapture(false, "", "snapshot");
        }
        function regionTemp(): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.startRegionCapture(true, "", "snapshot");
        }
        function regionCustom(path: string): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.startRegionCapture(false, root.capture.sanitizePath(path), "snapshot");
        }
        function ocr(): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.startRegionCapture(true, "", "ocr");
        }
        function lens(): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.startRegionCapture(true, "", "lens");
        }
        function full(): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.captureMonitor("");
        }
        function fullTemp(): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.captureMonitor(`${Paths.screenshotTempDir}/${root.capture.generateFilename()}`);
        }
        function fullCustom(path: string): void {
            if (!GlobalShortcuts.isLocked() && root.capture)
                root.capture.captureMonitor(`${root.capture.sanitizePath(path)}/${root.capture.generateFilename()}`);
        }
    }

    IpcHandler {
        target: "volume"

        function increaseVolume(vol: real): void {
            AudioService.increaseSinkVolume(vol);
            OnScreenDisplayService.show("volume");
        }
        function decreaseVolume(vol: real): void {
            AudioService.decreaseSinkVolume(vol);
            OnScreenDisplayService.show("volume");
        }
        function toggleVolumeMute(): void {
            AudioService.toggleSinkMuted();
            OnScreenDisplayService.show("volume");
        }
        function toggleMicMute(): void {
            AudioService.toggleSourceMuted();
            OnScreenDisplayService.show("mic");
        }
        function increaseMicVolume(vol: real): void {
            AudioService.increaseSourceVolume(vol);
            OnScreenDisplayService.show("mic");
        }
        function decreaseMicVolume(vol: real): void {
            AudioService.decreaseSourceVolume(vol);
            OnScreenDisplayService.show("mic");
        }
    }

    IpcHandler {
        target: "brightness"

        function increment(val: real): void {
            BrightnessService.increaseBrightness(val);
            OnScreenDisplayService.show("brightness");
        }
        function decrement(val: real): void {
            BrightnessService.decreaseBrightness(val);
            OnScreenDisplayService.show("brightness");
        }
    }

    IpcHandler {
        target: "clipboard"

        function reload(): void {
            ClipboardService.reload();
        }
        function wipe(): void {
            ClipboardService.wipe();
        }
    }

    IpcHandler {
        target: "colorpicker"

        function hex(): void {
            ColorPickerService.pick("hex", 0);
        }
        function rgb(): void {
            ColorPickerService.pick("rgb", 0);
        }
    }

    IpcHandler {
        target: "niri"

        function setDPMS(val: bool): void {
            NiriService.setDPMS(val);
        }
        function toggleDPMS(): void {
            NiriService.setDPMS(!GlobalSettings.monitorsPowered);
        }
        function focusApp(query: string): void {
            if (!GlobalShortcuts.isLocked())
                NiriService.focusApp(query);
        }
    }

    IpcHandler {
        target: "update"

        function refresh(): void {
            UpdateService.refresh();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(navigateBeforeLock: bool): void {
            LockService.lock(navigateBeforeLock);
        }

        function acquired(): bool {
            return LockService.acquired;
        }

        function unlock(): void {
            LockService.unlock();
        }
    }

    IpcHandler {
        target: "tasks"

        function reload(): void {
            TasksService.reload();
        }
    }

    IpcHandler {
        target: "alttab"

        function next(): void {
            if (!GlobalShortcuts.isLocked())
                AltTabService.switchNext();
        }
        function previous(): void {
            if (!GlobalShortcuts.isLocked())
                AltTabService.switchPrevious();
        }
        function activate(): void {
            if (!GlobalShortcuts.isLocked())
                AltTabService.activateSelected();
        }
        function close(): void {
            AltTabService.close();
        }
    }

    IpcHandler {
        target: "desktop"

        function wallpaper(wallpaperPath: string, isTemporaryWallpaper: bool, contentHash: string): void {
            DesktopService.selectWallpaper(wallpaperPath, isTemporaryWallpaper, contentHash);
        }
    }
}
