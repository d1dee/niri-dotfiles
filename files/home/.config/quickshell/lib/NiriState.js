// Native niri 26.04 event reducer. Unknown events intentionally leave state intact.
function empty() {
    return { windows: [], workspaces: [], previousFocusedWindowId: null };
}

function reduce(state, event) {
    const next = JSON.parse(JSON.stringify(state));
    const oldFocus = next.windows.find(w => w.is_focused);
    if (event.WorkspacesChanged) next.workspaces = event.WorkspacesChanged.workspaces;
    if (event.WindowsChanged) next.windows = event.WindowsChanged.windows;
    if (event.WorkspaceActivated) {
        const e = event.WorkspaceActivated;
        const workspace = next.workspaces.find(w => w.id === e.id);
        if (workspace) next.workspaces.forEach(w => {
            if (w.output === workspace.output) w.is_active = w.id === e.id;
            if (e.focused) w.is_focused = w.id === e.id;
        });
    }
    if (event.WorkspaceActiveWindowChanged) {
        const e = event.WorkspaceActiveWindowChanged;
        next.workspaces.forEach(w => { if (w.id === e.workspace_id) w.active_window_id = e.active_window_id; });
    }
    if (event.WorkspaceUrgencyChanged) {
        const e = event.WorkspaceUrgencyChanged;
        next.workspaces.forEach(w => { if (w.id === e.id) w.is_urgent = e.urgent; });
    }
    if (event.WindowOpenedOrChanged) {
        const window = event.WindowOpenedOrChanged.window;
        next.windows = next.windows.filter(w => w.id !== window.id);
        if (window.is_focused) next.windows.forEach(w => w.is_focused = false);
        next.windows.push(window);
    }
    if (event.WindowClosed) {
        const id = event.WindowClosed.id;
        next.windows = next.windows.filter(w => w.id !== id);
        next.workspaces.forEach(w => { if (w.active_window_id === id) w.active_window_id = null; });
    }
    if (event.WindowFocusChanged) next.windows.forEach(w => w.is_focused = w.id === event.WindowFocusChanged.id);
    if (event.WindowLayoutsChanged) {
        event.WindowLayoutsChanged.changes.forEach(pair => {
            const w = next.windows.find(w => w.id === pair[0]);
            if (w) w.layout = pair[1];
        });
    }
    if (event.WindowUrgencyChanged) {
        const e = event.WindowUrgencyChanged;
        next.windows.forEach(w => { if (w.id === e.id) w.is_urgent = e.urgent; });
    }
    if (event.WindowFocusTimestampChanged) {
        const e = event.WindowFocusTimestampChanged;
        next.windows.forEach(w => { if (w.id === e.id) w.focus_timestamp = e.focus_timestamp; });
    }
    const focus = next.windows.find(w => w.is_focused);
    if (oldFocus && (!focus || oldFocus.id !== focus.id)) next.previousFocusedWindowId = oldFocus.id;
    if (!next.windows.some(w => w.id === next.previousFocusedWindowId)) next.previousFocusedWindowId = null;
    return next;
}

function normalizeOutputs(raw) {
    const transforms = ["Normal", "90", "180", "270", "Flipped", "Flipped90", "Flipped180", "Flipped270"];
    return Object.keys(raw).sort().map(name => {
        const output = raw[name];
        const modes = output.modes || [];
        const mode = modes[output.current_mode] || modes.find(m => m.is_preferred) || modes[0] || {};
        const logical = output.logical || {};
        return Object.assign({}, output, {
            name: output.name || name, width: mode.width || 0, height: mode.height || 0,
            scale: logical.scale || 1, x: logical.x || 0, y: logical.y || 0,
            transform: Math.max(0, transforms.indexOf(logical.transform)),
            refreshRate: (mode.refresh_rate || 0) / 1000,
            availableModes: modes.map(m => `${m.width}x${m.height}@${m.refresh_rate / 1000}`),
            disabled: output.current_mode === null || !output.logical
        });
    });
}
