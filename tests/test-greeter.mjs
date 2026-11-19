import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Exercise the QML authentication handlers without a live PAM or greetd session.
const source = readFileSync(new URL('../files/home/.config/quickshell/greeter/GreeterService.qml', import.meta.url), 'utf8');

function handler(name) {
    const start = source.indexOf(`function ${name}(`);
    assert.notEqual(start, -1, `${name} exists`);
    let end = source.indexOf('{', start);
    let depth = 1;
    while (depth && ++end < source.length) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    assert.equal(depth, 0, `${name} is balanced`);
    return source.slice(start, end + 1);
}

function session() {
    const calls = [];
    const root = {
        isAuthenticating: false, authenticationHasFailed: false,
        awaitingResponse: false, responseEcho: false, echoResponse: '',
        _pendingPassword: '', _hasPendingPassword: false,
        _pendingSessionCmd: [], _pendingSessionType: '',
        _pendingSessionDesktop: '', _pendingDesktopNames: [],
    };
    const Greetd = {
        available: true,
        createSession: user => calls.push(['create', user]),
        respond: response => calls.push(['respond', response]),
        launch: (command, env) => calls.push(['launch', [...command], [...env]]),
    };
    const context = vm.createContext({ root, Greetd });
    for (const name of ['login', 'onAuthMessage', 'onAuthFailure', 'onError', 'onReadyToLaunch']) {
        vm.runInContext(handler(name), context);
    }
    const login = (password = 'secret') => context.login('demo', password, 'niri-session', 'wayland', 'niri', ['niri']);
    return { context, root, Greetd, calls, login };
}

{
    const { context, root, calls, login } = session();
    login();
    login('duplicate');
    assert.deepEqual(calls, [['create', 'demo']]);
    assert.deepEqual([...root._pendingSessionCmd], ['/bin/sh', '-c', 'niri-session']);
    context.onAuthMessage('Password:', false, true, false);
    assert.deepEqual(calls.at(-1), ['respond', 'secret']);
    assert.equal(root._pendingPassword, '');
    context.onAuthMessage('Verification code:', false, true, false);
    assert.equal(root.awaitingResponse, true);
    assert.equal(root.isAuthenticating, false);
    login('123456');
    assert.deepEqual(calls.at(-1), ['respond', '123456']);
    context.onReadyToLaunch();
    assert.deepEqual(calls.at(-1), ['launch', ['/bin/sh', '-c', 'niri-session'], [
        'XDG_SESSION_TYPE=wayland', 'XDG_SESSION_DESKTOP=niri',
        'DESKTOP_SESSION=niri', 'XDG_CURRENT_DESKTOP=niri',
    ]]);
    assert.equal(root.awaitingResponse, false);
}

for (const failure of ['onAuthFailure', 'onError']) {
    const { context, root, login } = session();
    login();
    context[failure]('Rejected');
    assert.equal(root.authenticationHasFailed, true);
    assert.equal(root.isAuthenticating, false);
    assert.equal(root.awaitingResponse, false);
    assert.equal(root._pendingPassword, '');
    assert.equal(root._hasPendingPassword, false);
    assert.equal(root.echoResponse, 'Rejected');
}

{
    const { context, root, calls, login } = session();
    login();
    context.onAuthMessage('Enter a visible response:', false, true, true);
    assert.deepEqual(calls, [['create', 'demo']], 'never send a stored password to an echoing prompt');
    assert.equal(root.awaitingResponse, true);
    assert.equal(root.responseEcho, true);
    assert.equal(root._pendingPassword, '');
}

{
    const { context, calls, login } = session();
    login('');
    context.onAuthMessage('Password:', false, true, false);
    assert.deepEqual(calls.at(-1), ['respond', '']);
}

{
    const { Greetd, root, calls, login } = session();
    Greetd.available = false;
    login();
    assert.deepEqual(calls, []);
    assert.equal(root.authenticationHasFailed, true);
}

assert.doesNotMatch(source, /killall/);
console.log('Greeter authentication handler tests passed (no live authentication).');
