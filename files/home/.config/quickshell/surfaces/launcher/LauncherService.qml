pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.surfaces.launcher.pages
import "../../store/LauncherData.js" as LauncherData
import "../../lib/FileUtils.js" as FileUtils

Singleton {
    id: root

    property var stack: []
    readonly property Item currentItem: stack.length > 0 ? stack[stack.length - 1] : null
    readonly property string currentItemName: currentItem ? (currentItem.objectName || "") : ""

    property bool ctrlHolded: false

    signal pushed(Item item, bool replace)
    signal popped
    signal resetStack

    Timer {
        id: resetTimer
        interval: 2 * 60 * 1000 // 2 minutes
        repeat: false
        onTriggered: root.reset()
    }

    Connections {
        target: GlobalStates
        function onShowLauncherChanged() {
            if (GlobalStates.showLauncher) {
                resetTimer.stop();
            } else {
                resetTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        const home = homeComponent.createObject(null, {
            objectName: "home"
        });
        if (!home) {
            console.error("LauncherService: failed to create initial home page, this is a fatal launcher error, keeping stack empty");
            return;
        }
        stack = [home];

        let map = {
            "calculator": calculatorComponent,
            "websearch": websearchComponent,
            "translate": translateComponent,
            "clipboard": clipboardComponent,
            "keybinds": keybindsComponent,
            "processes": processesComponent,
            "wallpaper": wallpaperComponent,
            "files": filesComponent,
            "emojis": emojisComponent,
            "tasks": tasksComponent,
            "monitors": monitorsComponent,
            "wallhaven": wallhavenComponent,
            "unsplash": unsplashComponent,
            "commands": commandsComponent
        };

        root._pageMap = map;
    }

    property var _pageMap: ({})

    function showDefPopup(def) {
        if (!def.popup)
            return;
        const title = def.popup.title ?? "";
        const message = def.popup.message ?? "";
        const duration = def.popup.duration ?? 2000;
        switch (def.popup.type) {
        case "success":
            GlobalIpc.popup.showSuccess(title, message, duration);
            break;
        case "warning":
            GlobalIpc.popup.showWarning(title, message, duration);
            break;
        case "error":
            GlobalIpc.popup.showError(title, message, duration);
            break;
        default:
            GlobalIpc.popup.showInfo(title, message, duration);
            break;
        }
    }

    function _handlePageAction(def, isPrimary) {
        if (isPrimary) {
            root.pushByName(def.page);

            if (!GlobalStates.showLauncher)
                GlobalStates.showLauncher = true;
        }
    }

    function _handleCommandAction(def, isPrimary) {
        if (def.exec) {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            Quickshell.execDetached(def.exec);
            showDefPopup(def);
            return;
        }

        if (def.actionType === "toggle_recording") {
            GlobalStates.showLauncher = false;
            const args = GlobalData.isRecording ? ["sh", "-c", `${Paths.screenRecordScript} stop quickshell notif`] : ["sh", "-c", `${Paths.screenRecordScript} start quickshell notif`];
            Quickshell.execDetached(args);
            return;
        }

        if (def.actionType === "reload_quickshell") {
            Quickshell.reload(false);
            return;
        }

        if (def.actionType === "save_tmp_wallpaper" || def.actionType === "save_tmp_wallpaper_hidden") {
            GlobalStates.showLauncher = false;
            const tmp = FileUtils.trimFileProtocol(Paths.wallpaperTmp);
            const hiddenArg = def.actionType === "save_tmp_wallpaper_hidden" ? " --hidden" : "";
            Quickshell.execDetached(["sh", "-c", `dest=$("${Paths.wallpaperFetcherScript}" save --source "${tmp}"${hiddenArg}); if [ -n "$dest" ]; then $BN_SCRIPTS/select-wallpaper --path "$dest"; fi`]);
            showDefPopup(def);
            return;
        }

        if (def.confirm && isPrimary) {
            GlobalStates.showLauncher = false;
            GlobalIpc.dialog.showConfirm(def.confirm[0], def.confirm[1], def.confirm[2], def.confirm[3], "", def.confirm[4]);
            return;
        }

        if (def.actionType === "colorpick" && isPrimary) {
            GlobalStates.showLauncher = false;
            ColorPickerService.pick(def.args[0], 0.2);
            return;
        }

        if (def.actionType === "toggle_blur") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            GlobalIpc.popup.showWarning("Blur Unavailable", "niri does not provide compositor blur.", 3000);
            return;
        }

        if (def.actionType === "toggle_window_shadows") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            NiriService.toggleAppearance("shadows");
            return;
        }

        if (def.actionType === "toggle_layer_shadows") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            GlobalSettings.enableShadow = !GlobalSettings.enableShadow;
            GlobalIpc.popup.showInfo(`Layer Shadows ${GlobalSettings.enableShadow ? "Enabled" : "Disabled"}`, "", 1500);
            return;
        }

        if (def.actionType === "toggle_window_transparency") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            NiriService.toggleAppearance("transparency");
            return;
        }

        if (def.actionType === "toggle_layer_transparency") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            GlobalSettings.transparentize = !GlobalSettings.transparentize;
            GlobalIpc.popup.showInfo(`Layer Transparency ${GlobalSettings.transparentize ? "Enabled" : "Disabled"}`, "", 1500);
            return;
        }

        if (def.actionType === "toggle_outer_gaps") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            NiriService.toggleAppearance("bigGaps");
            return;
        }

        if (def.actionType === "toggle_rounded_corners") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            NiriService.toggleAppearance("rounded");
            return;
        }

        if (def.actionType === "toggle_compact_bar") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            GlobalSettings.forceCompactBar = !GlobalSettings.forceCompactBar;
            GlobalIpc.popup.showInfo(`Compact Bar ${GlobalSettings.forceCompactBar ? "Enabled" : "Disabled"}`, "", 1500);
            return;
        }

        if (def.actionType === "toggle_lockscreen_blur") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            GlobalSettings.blurLockscreen = !GlobalSettings.blurLockscreen;
            GlobalIpc.popup.showInfo(`Lockscreen Blur ${GlobalSettings.blurLockscreen ? "Enabled" : "Disabled"}`, "", 1500);
            return;
        }

        if (def.actionType === "system_update") {
            if (isPrimary)
                GlobalStates.showLauncher = false;
            UpdateService.updateAll();
            return;
        }
    }

    function executeCommandById(id) {
        const command = commands.find(c => c.id === id);
        if (command) {
            command.primaryAction();
            return;
        }

        const page = pages.find(p => p.id === id);
        if (page) {
            page.primaryAction();
            return;
        }

        const app = HomeService.apps.find(a => a.id === id);
        if (app) {
            app.primaryAction();
            return;
        }
    }

    function pushByName(name, replace = false) {
        if (currentItem && currentItem.objectName === name)
            return;

        const component = _pageMap[name];
        if (!component) {
            console.warn(`LauncherService: unknown page name '${name}', ignoring push`);
            return;
        }
        const newPage = component.createObject(null, {
            objectName: name
        });
        if (!newPage) {
            console.error(`LauncherService: failed to create page '${name}', aborting push`);
            return;
        }
        push(newPage, replace);
    }

    function pushById(id, replace = false) {
        const def = LauncherData.pages.find(p => p.id === id);
        pushByName(def ? def.page : id, replace);
    }

    function push(item, replace = false) {
        let newStack = stack.slice();
        let oldItem = null;
        let didReplace = false;

        if (replace && newStack.length > 1) {
            oldItem = newStack.pop();
            didReplace = true;
        }

        newStack.push(item);
        stack = newStack;
        pushed(item, didReplace);

        if (oldItem) {
            Qt.callLater(() => oldItem.destroy());
        }
    }

    function pop() {
        if (stack.length > 1) {
            let newStack = stack.slice();
            let topItem = newStack.pop();
            stack = newStack;
            popped();
            Qt.callLater(() => topItem.destroy());
        }
    }

    function reset() {
        let itemsToDestroy = stack.slice();
        const home = homeComponent.createObject(null, {
            objectName: "home"
        });
        if (!home) {
            console.error("LauncherService: failed to create home page during reset, keeping current stack");
            return;
        }
        stack = [home];
        Qt.callLater(() => {
            resetStack();
            for (let i = 0; i < itemsToDestroy.length; i++) {
                itemsToDestroy[i].destroy();
            }
        });
    }

    function dynamicCommandName(def) {
        return HomeService.dynamicCommandName(def);
    }

    function dynamicCommandIcon(def) {
        return HomeService.dynamicCommandIcon(def);
    }

    readonly property var pages: HomeService.pagesData.map(def => {
        return Object.assign({}, def, {
            primaryAction: () => root._handlePageAction(def, true),
            secondaryAction: () => root._handlePageAction(def, false)
        });
    })

    readonly property var commands: HomeService.commandsData.map(def => {
        return Object.assign({}, def, {
            primaryAction: () => root._handleCommandAction(def, true),
            secondaryAction: () => root._handleCommandAction(def, false)
        });
    })

    // Page components
    Component {
        id: homeComponent
        Home {}
    }

    Component {
        id: calculatorComponent
        Calculator {}
    }

    Component {
        id: clipboardComponent
        Clipboard {}
    }

    Component {
        id: websearchComponent
        Websearch {}
    }

    Component {
        id: translateComponent
        Translate {}
    }

    Component {
        id: processesComponent
        Processes {}
    }

    Component {
        id: keybindsComponent
        Keybinds {}
    }

    Component {
        id: wallpaperComponent
        Wallpaper {}
    }

    Component {
        id: filesComponent
        Files {}
    }

    Component {
        id: emojisComponent
        Emojis {}
    }

    Component {
        id: tasksComponent
        Tasks {}
    }

    Component {
        id: monitorsComponent
        Monitors {}
    }

    Component {
        id: wallhavenComponent
        Wallhaven {}
    }

    Component {
        id: unsplashComponent
        Unsplash {}
    }

    Component {
        id: commandsComponent
        Commands {}
    }
}
