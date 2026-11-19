#!/usr/bin/env python3
"""Offline tests only: fake IPC, temporary config trees, real niri validate."""
import contextlib
import importlib.util
import io
import itertools
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "files/home/.config/quickshell/scripts/niri_settings.py"
spec = importlib.util.spec_from_file_location("niri_settings", SCRIPT)
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="test-niri-settings-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / "niri"
        self.directory.mkdir()
        self.directory.joinpath("config.kdl").write_text('include "outputs.kdl"\ninclude "appearance.kdl"\n')
        self.directory.joinpath("outputs.kdl").write_text("// initial outputs\n")
        self.directory.joinpath("appearance.kdl").write_text(settings.render_appearance(settings.DEFAULT_APPEARANCE))
        self.output = dict(name='DP-1', width=1920, height=1080, refreshRate=59.94, scale=1.25, x=-100, y=0, transform=1, disabled=False)

    def run_command(self, argv, **kwargs):
        result = io.StringIO()
        with patch.object(settings, "config_dir", return_value=self.directory), contextlib.redirect_stdout(result):
            settings.main(argv, **kwargs)
        return [json.loads(line) for line in result.getvalue().splitlines()]

    def test_all_appearance_combinations_validate(self):
        for values in itertools.product([False, True], repeat=4):
            data = dict(zip(settings.DEFAULT_APPEARANCE, values))
            with self.subTest(data=data):
                settings.validated_write(self.directory, "appearance.kdl", settings.render_appearance(data))

    def test_output_escaping_and_all_transforms_validate(self):
        for transform in range(8):
            output = dict(self.output, transform=transform, name='DP-1"; malicious { // \\')
            with self.subTest(transform=transform):
                settings.validated_write(self.directory, "outputs.kdl", settings.render_outputs([output]))
        settings.validated_write(self.directory, "outputs.kdl", settings.render_outputs([dict(self.output, disabled=True)]))

    def test_reject_invalid_output_fields(self):
        for field, value in [('scale', float('nan')), ('scale', '1; spawn "bad"'), ('x', 0.5), ('width', -1), ('transform', 8), ('name', 'DP\n1'), ('mirrorOf', 'DP-2'), ('disabled', 'false')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                settings.render_outputs([dict(self.output, **{field: value})])
        with self.assertRaises(ValueError):
            settings.render_outputs([self.output, self.output])

    def test_full_config_validation_failure_keeps_live_file(self):
        initial = self.directory.joinpath('outputs.kdl').read_text()
        self.directory.joinpath('config.kdl').write_text('invalid-option "no"\n')
        with self.assertRaises(ValueError):
            settings.validated_write(self.directory, 'outputs.kdl', settings.render_outputs([self.output]))
        self.assertEqual(self.directory.joinpath('outputs.kdl').read_text(), initial)

    def test_validation_process_failure_keeps_live_file(self):
        initial = self.directory.joinpath('outputs.kdl').read_text()
        with patch.object(settings.subprocess, 'run', side_effect=subprocess.TimeoutExpired('niri', 15)), self.assertRaises(subprocess.TimeoutExpired):
            settings.validated_write(self.directory, 'outputs.kdl', settings.render_outputs([self.output]))
        self.assertEqual(self.directory.joinpath('outputs.kdl').read_text(), initial)

    def test_appearance_persists_after_validation(self):
        response = self.run_command(['appearance', 'rounded', 'false'])[-1]
        self.assertFalse(response['appearance']['rounded'])
        self.assertFalse(self.run_command(['get'])[-1]['appearance']['rounded'])
        self.assertIn('geometry-corner-radius 0', self.directory.joinpath('appearance.kdl').read_text())

    def test_metadata_failure_restores_appearance(self):
        initial = self.directory.joinpath('appearance.kdl').read_text()
        with patch.object(settings, 'save_settings', side_effect=OSError('disk full')), self.assertRaises(OSError):
            self.run_command(['appearance', 'rounded', 'false'])
        self.assertEqual(self.directory.joinpath('appearance.kdl').read_text(), initial)

    def apply_with_confirmation(self, keep):
        # Finish after the first watchdog tick; no real compositor calls or timed wait.
        def tick(_):
            pending = json.loads(self.directory.joinpath('.bnsplit-pending.json').read_text())
            with settings.locked(self.directory):
                settings.finish_outputs(self.directory, pending['token'], keep)
        # Patch only the helper's clock: changing the shared time.sleep also
        # intercepts subprocess timeout polling and can deadlock nested flock.
        with patch.object(settings, 'time', SimpleNamespace(time=time.time, sleep=tick)):
            self.run_command(['outputs', json.dumps([self.output]), json.dumps(['DP-1'])])

    def test_confirm_and_revert_transactions(self):
        initial = self.directory.joinpath('outputs.kdl').read_text()
        self.apply_with_confirmation(False)
        self.assertEqual(self.directory.joinpath('outputs.kdl').read_text(), initial)
        self.apply_with_confirmation(True)
        self.assertIn('1920x1080@59.94', self.directory.joinpath('outputs.kdl').read_text())
        self.assertEqual(settings.load_settings(self.directory)['outputs'][0]['name'], 'DP-1')
        self.assertFalse(self.directory.joinpath('.bnsplit-pending.json').exists())

    def test_preserves_disconnected_saved_outputs(self):
        data = settings.load_settings(self.directory)
        data['outputs'] = [dict(self.output, name='unplugged')]
        settings.save_settings(self.directory, data)
        self.apply_with_confirmation(True)
        self.assertEqual({c['name'] for c in settings.load_settings(self.directory)['outputs']}, {'DP-1', 'unplugged'})

    def test_watchdog_expiry_and_startup_recovery(self):
        initial = self.directory.joinpath('outputs.kdl').read_text()
        clock = [100.0]
        with patch.object(settings, 'time', SimpleNamespace(time=lambda: clock[0], sleep=lambda _: clock.__setitem__(0, 113.0))):
            response = self.run_command(['outputs', json.dumps([self.output]), json.dumps(['DP-1'])])
        self.assertEqual(response[-1]['status'], 'reverted')
        self.assertEqual(self.directory.joinpath('outputs.kdl').read_text(), initial)
        pending = dict(token='stale', previous=initial, outputs=[], deadline=settings.time.time() + 100)
        self.directory.joinpath('.bnsplit-pending.json').write_text(json.dumps(pending))
        self.directory.joinpath('outputs.kdl').write_text(settings.render_outputs([self.output]))
        self.run_command(['get'])
        self.assertEqual(self.directory.joinpath('outputs.kdl').read_text(), initial)

    def test_stale_token_and_expired_confirmation(self):
        pending = dict(token='right', previous='// previous\n', outputs=[], deadline=0)
        self.directory.joinpath('.bnsplit-pending.json').write_text(json.dumps(pending))
        self.assertFalse(settings.finish_outputs(self.directory, 'wrong', True))
        with self.assertRaises(ValueError):
            settings.finish_outputs(self.directory, 'right', True)
        self.assertEqual(self.directory.joinpath('outputs.kdl').read_text(), '// previous\n')

    def test_opaque_workspace_ipc(self):
        class FakeSocket:
            request = None
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def settimeout(self, timeout): self.timeout = timeout
            def connect(self, path): self.path = path
            def sendall(self, request): self.request = json.loads(request)
            def makefile(self, mode): return io.BytesIO(b'{"Ok":"Handled"}\n')
        connection = FakeSocket()
        with patch.object(settings.socket, 'socket', return_value=connection), patch.dict(settings.os.environ, {'NIRI_SOCKET': '/fake/socket'}):
            settings.main(['focus-workspace', '991'])
        self.assertEqual(connection.request, {'Action': {'FocusWorkspace': {'reference': {'Id': 991}}}})


if __name__ == '__main__':
    unittest.main()
