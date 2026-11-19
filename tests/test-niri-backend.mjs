import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const base = new URL('../files/home/.config/quickshell/', import.meta.url);
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('lib/NiriState.js', base), 'utf8'), context);
const plain = value => JSON.parse(JSON.stringify(value));
let state = context.empty();
function event(value) { state = context.reduce(state, value); }
event({ WorkspacesChanged: { workspaces: [
    { id: 991, idx: 1, output: 'DP-1', is_active: true, is_focused: true, active_window_id: 0 },
    { id: 42, idx: 2, output: 'DP-1', is_active: false, is_focused: false, active_window_id: 8 },
    { id: 80, idx: 1, output: 'HDMI-A-1', is_active: true, is_focused: false, active_window_id: null },
] } });
event({ WindowsChanged: { windows: [
    { id: 0, title: 'zero', app_id: 'foo', workspace_id: 991, is_focused: true, layout: {} },
    { id: 8, title: 'eight', app_id: 'foo', workspace_id: 42, is_focused: false, layout: {} },
] } });
const before = plain(state);
event({ WindowFocusChanged: { id: 8 } });
assert.equal(state.previousFocusedWindowId, 0);
assert.equal(before.windows[0].is_focused, true, 'reducer must not mutate previous snapshots');
assert.equal(state.windows.filter(w => w.is_focused).length, 1);
event({ WorkspaceActivated: { id: 42, focused: true } });
assert.equal(state.workspaces.find(w => w.id === 991).is_active, false);
assert.equal(state.workspaces.find(w => w.id === 80).is_active, true, 'other output retains active workspace');
event({ WorkspaceActivated: { id: 991, focused: false } });
assert.equal(state.workspaces.find(w => w.is_focused).id, 42, 'activation is not necessarily focus');
event({ WindowOpenedOrChanged: { window: { id: 0, title: 'updated', app_id: 'foo', workspace_id: 42, is_focused: true, layout: {} } } });
assert.equal(state.windows.length, 2);
assert.equal(state.previousFocusedWindowId, 8);
event({ WindowLayoutsChanged: { changes: [[0, { tile_size: [100, 200] }], [999, {}]] } });
event({ WindowUrgencyChanged: { id: 0, urgent: true } });
event({ WindowFocusTimestampChanged: { id: 0, focus_timestamp: { secs: 3, nanos: 4 } } });
event({ WorkspaceUrgencyChanged: { id: 42, urgent: true } });
assert.deepEqual(plain(state.windows.find(w => w.id === 0).layout), { tile_size: [100, 200] });
assert.equal(state.workspaces.find(w => w.id === 42).is_urgent, true);
event({ WindowFocusChanged: { id: null } });
assert.equal(state.windows.some(w => w.is_focused), false);
event({ WorkspaceActiveWindowChanged: { workspace_id: 42, active_window_id: 0 } });
event({ WindowClosed: { id: 0 } });
assert.equal(state.workspaces.find(w => w.id === 42).active_window_id, null);
assert.equal(state.previousFocusedWindowId, null);
const stable = plain(state);
event({ FutureEvent: { value: 1 } });
assert.deepEqual(plain(state), stable);
event({ WindowsChanged: { windows: [] } });
event({ WorkspacesChanged: { workspaces: [] } });
assert.deepEqual(plain(state), { windows: [], workspaces: [], previousFocusedWindowId: null });

const outputs = context.normalizeOutputs({ 'DP-1': {
    name: 'DP-1', current_mode: 1, modes: [
        { width: 1920, height: 1080, refresh_rate: 60000, is_preferred: true },
        { width: 1920, height: 1080, refresh_rate: 59940 },
    ], logical: { x: -100, y: 20, width: 864, height: 1536, scale: 1.25, transform: '90' },
}, 'DP-2': { name: 'DP-2', current_mode: null, logical: null, modes: [{ width: 800, height: 600, refresh_rate: 60000, is_preferred: true }] } });
assert.equal(outputs[0].refreshRate, 59.94);
assert.equal(outputs[0].transform, 1);
assert.equal(outputs[0].logical.width, 864);
assert.equal(outputs[0].x, -100);
assert.equal(outputs[1].disabled, true);
assert.equal(outputs[1].width, 800);
assert.equal(context.normalizeOutputs({}).length, 0);

const qml = fs.readFileSync(new URL('services/NiriService.qml', base), 'utf8');
function method(name) {
    const start = qml.indexOf(`function ${name}(`);
    assert.notEqual(start, -1);
    let end = qml.indexOf('{', start), depth = 1;
    while (depth) { end++; if (qml[end] === '{') depth++; if (qml[end] === '}') depth--; }
    return qml.slice(start, end + 1);
}
const calls = [];
const api = vm.createContext({
    AppUtils: { normalizeAppId: q => String(q ?? '').trim().replace(/\.desktop$/i, '').toLowerCase() },
    windows: [{ id: 1, app_id: 'foo', title: 'one' }, { id: 0, app_id: 'FOO', title: 'two', is_focused: true }, { id: 9, app_id: 'kitty', title: 'package-install' }],
    outputs: [{ name: 'DP-1' }], focusedOutput: 'DP-1',
    action: argv => calls.push(argv), focusWindow: id => calls.push(id),
    GlobalSettings: { monitorsPowered: true },
});
for (const name of ['focusApp', 'getMonitorOfScreen', 'spawn', 'setDPMS']) vm.runInContext(method(name), api);
api.focusApp(' foo.DESKTOP ');
assert.equal(calls.pop(), 0);
api.focusApp('fo');
assert.equal(calls.length, 0, 'no app/title substring fallback');
api.focusApp('package-install');
assert.equal(calls.pop(), 9);
assert.equal(api.getMonitorOfScreen({ name: 'missing' }), null);
assert.equal(api.getMonitorOfScreen(null).name, 'DP-1');
api.spawn(['kitty', 'space argument', '$(untrusted)']);
assert.deepEqual(plain(calls.pop()), ['spawn', '--', 'kitty', 'space argument', '$(untrusted)']);
api.setDPMS(false);
assert.deepEqual(plain(calls.pop()), ['power-off-monitors']);
assert.equal(api.GlobalSettings.monitorsPowered, false);
assert.match(qml, /Math\.min\(root.retryDelay \* 2, 30000\)/);
assert.match(qml, /root\.state = NiriState\.empty\(\)/);
assert.match(qml, /\["niri", "msg", "-j", "event-stream"\]/);
console.log('PASS niri reducer, output normalization and backend API mocks');
