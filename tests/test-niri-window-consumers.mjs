import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const base = new URL('../files/home/.config/quickshell/', import.meta.url);
const read = path => fs.readFileSync(new URL(path, base), 'utf8');
const plain = value => JSON.parse(JSON.stringify(value));
const appUtils = vm.createContext({ FuzzyFilter: { search: () => [] } });
vm.runInContext(read('lib/AppUtils.js').replace(/^\.(?:pragma|import).*$/gm, ''), appUtils);
const app = { id: 'Org.Example.App.DESKTOP', startupClass: 'ExampleApp', icon: 'example-icon', actions: [] };
const windows = [
    { id: 0, app_id: 'org.example.app', title: 'First' },
    { id: 8, app_id: 'ExampleApp', title: 'Focused', is_focused: true },
    { id: 12, app_id: 'org.example.app.helper', title: 'Not the app' }
];
assert.equal(appUtils.normalizeAppId(' Org.Example.App.DESKTOP '), 'org.example.app');
assert.equal(appUtils.normalizeAppId(null), '');
assert.equal(appUtils.findWindowForApp(app, windows).id, 8);
assert.equal(appUtils.findWindowForApp(app, windows.slice(0, 1)).id, 0);
assert.equal(appUtils.findWindowForApp(app, windows.slice(2)), null);
assert.equal(appUtils.findWindowForApp({ id: '' }, [{ app_id: null }]), null);
assert.equal(appUtils.getAppIcon('org.example.app', [app]), 'example-icon');
assert.equal(appUtils.getAppIcon('EXAMPLEAPP', [app]), 'example-icon');

// Extract the actual QML function bodies, without loading a shell or compositor.
function loadFunctions(path, context) {
    const source = read(path);
    const functions = source.match(/^    function \w+\([^]*?^    \}/gm) ?? [];
    vm.runInContext(functions.join('\n').replace(/:\s*(?:string|bool|int)\b/g, ''), context);
    return source;
}
function expression(source, name) {
    const match = source.match(new RegExp(`^    readonly property \\w+ ${name}: (.+)$`, 'm'));
    assert.ok(match, `missing property ${name}`);
    return match[1];
}

const focused = [];
const state = vm.createContext({
    AppUtils: appUtils,
    NiriService: { windows: [], focusedWindow: null, previousFocusedWindowId: null, focusWindow: id => focused.push(id) },
    GlobalStates: { showAltTabSwitcher: false },
    flattenedToplevels: [], selectedIndex: 0,
    itemsPerPage: 9, rowsPerPage: 3, itemsPerRow: 3
});
state.root = state;
const altTab = loadFunctions('services/AltTabService.qml', state);
const ids = () => plain(state.flattenedToplevels.map(w => w.id));
state.switchNext();
assert.equal(state.GlobalStates.showAltTabSwitcher, false);
state.NiriService.windows = [{ id: 0, app_id: null, title: '' }];
state.switchNext();
assert.equal(state.selectedIndex, 0);
state.activateSelected();
assert.deepEqual(focused, [0]);
assert.equal(state.GlobalStates.showAltTabSwitcher, false);
state.NiriService.windows = [
    { id: 2, app_id: 'browser', title: 'Two' },
    { id: 4, app_id: 'editor', title: 'Four' },
    { id: 9, app_id: 'terminal', title: 'Nine' },
    { id: 6, app_id: 'QUICKSHELL', title: 'Shell' }
];
state.NiriService.focusedWindow = state.NiriService.windows[1];
state.NiriService.previousFocusedWindowId = 9;
state.switchNext();
assert.deepEqual(ids(), [4, 9, 2]);
assert.equal(state.selectedIndex, 1);
state.switchNext();
assert.equal(state.selectedIndex, 2);
state.switchNext();
assert.equal(state.selectedIndex, 0);
state.switchPrevious();
assert.equal(state.selectedIndex, 2);
state.selectedIndex = 1;
state.NiriService.windows = [
    { id: 9, app_id: 'terminal', title: 'Renamed' },
    { id: 2, app_id: 'browser', title: 'Two' },
    { id: 21, app_id: 'other', title: 'New' }
];
state.syncWindows();
assert.deepEqual(ids(), [9, 2, 21]);
assert.equal(state.selectedIndex, 0);
assert.equal(state.flattenedToplevels[0].title, 'Renamed');
assert.equal(state.getToplevelFlatIndex({ id: 2 }), 1);
state.selectAndActivate(2);
assert.deepEqual(focused, [0, 21]);
state.switchPrevious();
assert.equal(state.selectedIndex, 2);
state.NiriService.windows = state.NiriService.windows.slice(0, 1);
state.syncWindows();
assert.equal(state.selectedIndex, 0);
state.NiriService.windows = [];
state.syncWindows();
assert.equal(state.GlobalStates.showAltTabSwitcher, false);
state.flattenedToplevels = Array.from({ length: 20 }, (_, id) => ({ id }));
const pages = altTab.match(/property var windowPages: \{([^]*?)^    \}/m)[1];
assert.deepEqual(plain(vm.runInContext(`(function() {${pages}})()`, state)).map(page => page.map(row => row.length)), [[3, 3, 3], [3, 3, 3], [2]]);

const home = vm.createContext({
    GlobalStates: { showLauncher: true }, NiriService: { focusWindow: id => focused.push(id) },
    GlobalData: {}, Quickshell: { execDetached: () => assert.fail('must focus existing window') }
});
home.root = home;
loadFunctions('services/HomeService.qml', home);
const entry = home._buildAppEntry(app, 0, true, null);
entry.primaryAction();
assert.equal(focused.at(-1), 0);
assert.equal(home.GlobalStates.showLauncher, false);

const workspaceSource = read('surfaces/bar/modules/Workspaces.qml');
const workspaceCalls = [];
const workspaces = vm.createContext({
    outputName: 'DP-2',
    NiriService: {
        workspaces: [
            { id: 1, idx: 10, output: 'DP-2', is_active: true },
            { id: 777, idx: 2, output: 'DP-2' },
            { id: 123, idx: 1, output: 'DP-1', is_focused: true }
        ],
        focusWorkspace: id => workspaceCalls.push(id)
    }
});
workspaces.sortedWorkspaces = vm.runInContext(expression(workspaceSource, 'sortedWorkspaces'), workspaces);
assert.deepEqual(plain(workspaces.sortedWorkspaces.map(w => w.id)), [777, 1]);
assert.equal(vm.runInContext(expression(workspaceSource, 'focusedIndex'), workspaces), 1);
const click = workspaceSource.match(/onClicked: (NiriService.focusWorkspace\(.+\))/)[1];
workspaces.parent = { modelData: workspaces.sortedWorkspaces[0] };
vm.runInContext(click, workspaces);
assert.deepEqual(workspaceCalls, [777]);
assert.match(workspaceSource, /text: parent.isReal \? parent.modelData.idx : ""/);

const commands = [];
const desktop = vm.createContext({
    NiriService: {}, GlobalData: { wallpaperPath: '/wallpaper with spaces.jpg' },
    Paths: { desktopWidgetScript: '/script with spaces.py' },
    mainMonitor: { width: 3840, height: 2160, scale: 2, logical: { width: 1920, height: 1080 } },
    mainScreen: { width: 1920, height: 1080 },
    clockWidgetWidth: 300, clockWidgetHeight: 125, wallpaperContentHash: '', fetchPending: false,
    dataFetcher: { running: false, exec: argv => commands.push(plain(argv)) },
    Qt: { size: (width, height) => ({ width, height }) }
});
desktop.root = desktop;
const desktopSource = loadFunctions('services/DesktopService.qml', desktop);
const monitorLookup = desktopSource.match(/readonly property var mainMonitor: \{([^]*?)^    \}/m)[1];
desktop.mainScreen.name = 'DP-1';
desktop.NiriService.getMonitorOfScreen = () => ({ name: 'DP-2', logical: { width: 800, height: 600 } });
assert.equal(vm.runInContext(`(function() {${monitorLookup}})()`, desktop), null);
desktop.NiriService.getMonitorOfScreen = () => ({ name: 'DP-1', logical: { width: 1920, height: 1080 } });
assert.equal(vm.runInContext(`(function() {${monitorLookup}})()`, desktop).name, 'DP-1');
const placement = expression(desktopSource, 'placementSize');
desktop.placementSize = vm.runInContext(placement, desktop);
assert.deepEqual(plain(desktop.placementSize), { width: 1920, height: 1080 });
desktop.refresh();
assert.deepEqual(commands[0], ['python3', '/script with spaces.py', '/wallpaper with spaces.jpg', '--screen-width', '1920', '--screen-height', '1080', '--widget-width', '300', '--widget-height', '125']);
desktop.mainMonitor = { width: 3840, height: 2160, scale: 1.5, logical: { width: 1440, height: 2560 } };
desktop.placementSize = vm.runInContext(placement, desktop);
desktop.wallpaperContentHash = 'hash';
desktop.refresh();
assert.equal(commands[1][4], '1440');
assert.equal(commands[1][6], '2560');
assert.deepEqual(commands[1].slice(-2), ['--content-hash', 'hash']);
desktop.dataFetcher.running = true;
desktop.refresh();
assert.equal(desktop.fetchPending, true);
assert.equal(commands.length, 2);
desktop.text = '{"x":120,"y":90,"brightness":42}';
const stdout = desktopSource.match(/onStreamFinished: \{([^]*?)^            \}/m)[1];
vm.runInContext(`(function() {${stdout}})()`, desktop);
assert.equal(desktop.GlobalData.desktopWidgetData, undefined);
desktop.fetchPending = false;
vm.runInContext(`(function() {${stdout}})()`, desktop);
assert.deepEqual(plain(desktop.GlobalData.desktopWidgetData), { x: 120, y: 90, brightness: 42 });
desktop.mainMonitor = { logical: null };
assert.deepEqual(plain(vm.runInContext(placement, desktop)), { width: 1920, height: 1080 });
desktop.mainMonitor = null;
desktop.refresh();
assert.equal(commands.length, 2);

const ownedFiles = [
    'services/DesktopService.qml', 'services/HomeService.qml', 'services/AltTabService.qml', 'lib/AppUtils.js',
    'surfaces/bar/Bar.qml', 'surfaces/bar/modules/Workspaces.qml', 'surfaces/bar/modules/MprisPlayers.qml',
    'surfaces/notifications/NotificationPopups.qml', 'surfaces/alttab/AltTabSwitcher.qml'
];
for (const path of ownedFiles)
    assert.doesNotMatch(read(path), /Hyprland|hyprctl|ScreencopyView|lastIpcObject|lastFocusedWindowAddress/, path);
assert.doesNotMatch(read('surfaces/bar/Bar.qml'), /visibleMask|\.hasFullscreen/);
assert.match(read('surfaces/bar/Bar.qml'), /compactBar: GlobalSettings.forceCompactBar/);
assert.doesNotMatch(read('surfaces/notifications/NotificationPopups.qml'), /\.maximized|\.hasFullscreen/);
assert.match(read('surfaces/bar/modules/MprisPlayers.qml'), /NiriService.focusApp\(currentPlayer.player.desktopEntry\)/);
console.log('PASS: niri consumer app IDs/icons, numeric focus IDs, MRU/cycling/live updates/paging, workspace identity/labels, logical geometry and argv, compositor-only API removal');
