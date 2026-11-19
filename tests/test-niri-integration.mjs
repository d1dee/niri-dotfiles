import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = dirname(dirname(fileURLToPath(import.meta.url)));
const home = join(repo, 'files/home');
const text = path => readFileSync(join(repo, path), 'utf8');

function inspect(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const path = join(directory, entry.name);
        if (entry.isDirectory()) {
            inspect(path);
        } else if (entry.isFile() && (/\.(qml|kdl|conf|toml|js|sh|py)$/.test(entry.name) || directory.endsWith('/scripts'))) {
            const content = readFileSync(path, 'utf8');
            assert.doesNotMatch(content, /Quickshell\.Hyprland|HyprlandService|\bhyprctl\b|\bstart-hyprland\b|\bhypridle\b|\bhyprlock\b|\bhyprpicker\b|HYPRLAND_INSTANCE_SIGNATURE/, relative(repo, path));
        }
    }
}
inspect(join(home, '.config'));
inspect(join(home, '.local/share/bnsplit/scripts'));

const config = text('files/home/.config/niri/config.kdl');
assert.match(config, /include "outputs\.kdl"/);
assert.match(config, /include "appearance\.kdl"/);
assert.match(config, /spawn-at-startup "niri-idle"/);
assert.match(config, /Mod\+Delete[^\n]+spawn "niri-lock"/);
assert.doesNotMatch(config, /^\s*GDK_BACKEND\s+/m);
for (const helper of ['niri-lock', 'niri-idle', 'qs-nothp', 'xdg-desktop-portal-wallpaper-bnsplit']) {
    assert.ok(statSync(join(home, '.local/share/bnsplit/scripts', helper)).mode & 0o111, `${helper} is executable`);
}

const ipc = text('files/home/.config/quickshell/GlobalIpc.qml');
assert.match(ipc, /function acquired\(\): bool\s*\{\s*return LockService\.acquired;/);
assert.match(ipc, /target: "niri"/);
assert.match(ipc, /startRegionCapture\(true, "", "lens"\)/);
assert.match(ipc, /startRegionCapture\(true, "", "ocr"\)/);
assert.doesNotMatch(ipc, /screensharepicker/);
assert.doesNotMatch(text('files/home/.config/quickshell/shell.qml'), /ScreenShareService|ScreenSharePicker/);
const lock = text('files/home/.config/quickshell/lock/LockContent.qml');
assert.match(lock, /onSecureChanged: LockService\.acquired = root\.secure/);
assert.match(lock, /Quickshell\.screens\[0\]/);
assert.match(text('files/home/.config/xdg-desktop-portal/niri-portals.conf'), /ScreenCast=gnome;/);
assert.match(text('files/home/.config/xdg-desktop-portal/niri-portals.conf'), /Wallpaper=bnsplit;/);
assert.match(text('files/root/usr/local/share/xdg-desktop-portal/portals/bnsplit.portal'), /DBusName=org.freedesktop.impl.portal.desktop.wallpaperbnsplit/);
assert.match(text('files/home/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wallpaperbnsplit.service'), /Name=org.freedesktop.impl.portal.desktop.wallpaperbnsplit/);
assert.match(text('files/home/.config/quickshell/store/LauncherData.js'), /niri-lock\\" --suspend/);

for (const path of [
    'files/home/.config/niri/config.kdl',
    'files/home/.config/quickshell/greeter/niri.kdl',
]) {
    execFileSync('niri', ['validate', '--config', join(repo, path)], { stdio: 'pipe' });
}
console.log('PASS: niri desktop/greeter KDL, compositor dependency removal, portal, shortcut and secure-lock wiring');
