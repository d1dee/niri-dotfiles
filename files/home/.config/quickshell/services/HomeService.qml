pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import "../store/LauncherData.js" as LauncherData
import "../lib/FuzzyFilter.js" as FuzzyFilter
import "../lib/AppUtils.js" as AppUtils
import "../lib/FileUtils.js" as FileUtils

Singleton {
    id: root

    property string searchText: ""
    property var searchFields: ["name", "id", "description"]

    property var _entryCache: ({})

    function incrementScore(id, type) {
        if (type === "command" || type === "page")
            return;
        let scores = Object.assign({}, GlobalData.launcherSuggestionsScores || {});
        const now = Date.now();
        const halfLifeMs = 14 * 24 * 60 * 60 * 1000;

        function decayedScore(entry) {
            const ageMs = now - (entry.lastUsed || now);
            const decayFactor = Math.pow(0.5, ageMs / halfLifeMs);
            return entry.score * decayFactor;
        }

        const existing = scores[id];
        scores[id] = {
            id: id,
            score: +(((existing?.score || 0) + 0.01).toFixed(4)),
            lastUsed: now,
            type: type
        };

        let sortedEntries = Object.entries(scores).sort((a, b) => decayedScore(b[1]) - decayedScore(a[1]));

        let newScores = {};
        for (let i = 0; i < sortedEntries.length; i++) {
            newScores[sortedEntries[i][0]] = sortedEntries[i][1];
        }

        GlobalData.launcherSuggestionsScores = newScores;
    }

    function _cachedEntry(key, inputs, build) {
        const hit = root._entryCache[key];
        if (hit) {
            let same = true;
            for (const k in inputs) {
                if (hit.inputs[k] !== inputs[k]) {
                    same = false;
                    break;
                }
            }
            if (same)
                return hit.entry;
        }
        const entry = build();
        root._entryCache[key] = {
            entry: entry,
            inputs: inputs
        };
        return entry;
    }

    function _buildAppEntry(app, windowId, isOpen, override) {
        const openNewWindow = () => {
            if (override && override.primaryAction) {
                Quickshell.execDetached(["sh", "-c", override.primaryAction]);
            } else if (app.runInTerminal) {
                const command = ["sh", "-c", "kitty " + `"${app.execString.split('%')[0].trim()}"`];
                Quickshell.execDetached(command);
            } else if (app.execute && typeof app.execute === 'function') {
                app.execute();
            } else if (app.execString) {
                const command = ["sh", "-c", app.execString];
                Quickshell.execDetached(command);
            }
            incrementScore(app.id, "application");
        };

        return {
            type: "application",
            id: app.id,
            name: app.name,
            description: app.comment,
            icon: app.icon,
            iconType: "theme",
            showIndicator: isOpen,
            enabled: true,
            primaryAction: () => {
                GlobalStates.showLauncher = false;
                if (windowId !== null) {
                    NiriService.focusWindow(windowId);
                } else if (override && override.primaryAction) {
                    Quickshell.execDetached(["sh", "-c", override.primaryAction]);
                    incrementScore(app.id, "application");
                } else {
                    openNewWindow();
                }
            },
            secondaryAction: () => {
                GlobalStates.showLauncher = false;
                if (override && override.secondaryAction) {
                    Quickshell.execDetached(["sh", "-c", override.secondaryAction]);
                    incrementScore(app.id, "application");
                } else if (app.actions.length > 0) {
                    app.actions[0].execute();
                    incrementScore(app.id, "application");
                } else {
                    openNewWindow();
                }
            }
        };
    }

    readonly property var apps: {
        const seen = {};
        const list = [...new Set(DesktopEntries.applications.values)].map(app => {
            const window = AppUtils.findWindowForApp(app, NiriService.windows);
            const windowId = window?.id ?? null;
            const isOpen = window !== null;
            const override = GlobalSettings.launcherOverrides.find(o => o.id === app.id);
            const key = "app:" + app.id;
            seen[key] = true;
            return root._cachedEntry(key, {
                windowId: windowId,
                isOpen: isOpen,
                overridePrimary: override?.primaryAction ?? "",
                overrideSecondary: override?.secondaryAction ?? "",
                name: app.name,
                description: app.comment,
                icon: app.icon
            }, () => root._buildAppEntry(app, windowId, isOpen, override));
        }).sort((a, b) => a.name.localeCompare(b.name));
        for (const k in root._entryCache) {
            if (k.startsWith("app:") && !seen[k])
                delete root._entryCache[k];
        }
        return list;
    }

    function dynamicCommandName(def) {
        switch (def.actionType) {
        case "toggle_recording":
            return GlobalData.isRecording ? "Stop Recording" : "Start Recording";
        case "toggle_lockscreen_blur":
            return GlobalSettings.blurLockscreen ? "Disable Lockscreen Blur" : "Enable Lockscreen Blur";
        case "toggle_layer_shadows":
            return GlobalSettings.enableShadow ? "Disable Layer Shadows" : "Enable Layer Shadows";
        case "toggle_layer_transparency":
            return GlobalSettings.transparentize ? "Disable Layer Transparency" : "Enable Layer Transparency";
        case "toggle_rounded_corners":
            return GlobalSettings.enableRounding ? "Disable Rounded Corners" : "Enable Rounded Corners";
        case "toggle_compact_bar":
            return GlobalSettings.forceCompactBar ? "Disable Compact Bar" : "Enable Compact Bar";
        default:
            return def.name;
        }
    }

    function dynamicCommandIcon(def) {
        if (def.actionType === "toggle_recording")
            return GlobalData.isRecording ? "videocam_off" : "videocam";
        return def.icon;
    }

    readonly property var pagesData: LauncherData.pages.map(def => {
        return root._cachedEntry("page:" + def.id, {
            name: def.name,
            description: def.desc,
            icon: def.icon,
            iconType: def.iconType
        }, () => ({
                    type: "page",
                    id: def.id,
                    name: def.name,
                    description: def.desc,
                    icon: def.icon,
                    iconType: def.iconType,
                    showIndicator: false,
                    enabled: true,
                    page: def.page
                }));
    })

    function _commandEnabled(def) {
        const restrictedActions = ["toggle_blur", "toggle_window_shadows", "toggle_layer_shadows", "toggle_window_transparency", "toggle_layer_transparency"];
        if (restrictedActions.includes(def.actionType) && GlobalSettings.isPowerSaverEnabled)
            return false;

        if (def.isTemporaryWallpaperCheck)
            return GlobalData.wallpaperPath === FileUtils.trimFileProtocol(Paths.wallpaperTmp);
        if (def.isUpdateCheck)
            return !UpdateService.dbLock;
        return true;
    }

    readonly property var commandsData: LauncherData.commands.map(def => {
        const name = root.dynamicCommandName(def);
        const icon = root.dynamicCommandIcon(def);
        const enabled = root._commandEnabled(def);
        return root._cachedEntry("command:" + def.id, {
            name: name,
            icon: icon,
            enabled: enabled
        }, () => Object.assign({}, def, {
                type: "command",
                id: def.id,
                name: name,
                description: def.desc,
                icon: icon,
                iconType: def.iconType,
                showIndicator: false,
                enabled: enabled
            }));
    })

    readonly property var suggestions: {
        const scores = Object.values(GlobalData.launcherSuggestionsScores || {});
        const out = [];
        for (const entry of scores) {
            let item = null;
            if (entry.type === "application") {
                item = apps.find(a => a.id === entry.id) || null;
            } else if (entry.type === "command") {
                item = commandsData.find(c => c.id === entry.id) || null;
            }
            if (item !== null)
                out.push(item);
        }
        return out;
    }

    readonly property var homeItems: {
        const query = searchText.trim();
        const scores = GlobalData.launcherSuggestionsScores || {};
        const seen = new Set();
        return FuzzyFilter.search(query, [...suggestions, ...apps, ...pagesData, ...commandsData], {
            threshold: 0,
            limit: 999,
            all: true,
            keys: searchFields,
            scoreFn: i => i.score + (scores[i.obj.id]?.score ?? 0)
        }).filter(item => {
            if (seen.has(item.id) || !item.enabled)
                return false;
            seen.add(item.id);
            return true;
        });
    }
}
