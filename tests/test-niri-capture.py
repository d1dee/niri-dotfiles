#!/usr/bin/env python3
"""Exercise capture helpers with fake compositor/recorder/desktop commands only."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
QS = ROOT / "files/home/.config/quickshell"
MOCK = r'''
import json, os, pathlib, signal, sys, time
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "niri":
    if "focused-output" in args:
        print(json.dumps({"name": "DP-1"}))
    elif os.environ.get("MOCK_CAPTURE") == "error":
        sys.exit(7)
    elif "--path" in args:
        path = pathlib.Path(args[args.index("--path") + 1])
        pathlib.Path(os.environ["MOCK_CAPTURE_PATH"]).write_text(str(path))
        path.write_text("complete-image" if os.environ.get("MOCK_CAPTURE") not in ("incomplete", "deferred") else "")
elif name == "magick":
    sys.exit(0 if pathlib.Path(args[-1]).read_text() == "complete-image" else 1)
elif name == "gpu-screen-recorder":
    if "--help" in args:
        print("portal -write-first-frame-ts" if os.environ.get("MOCK_RECORDER") != "unsupported" else "old recorder")
    else:
        signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
        if os.environ.get("MOCK_RECORDER") == "error":
            sys.exit(13)
        path = pathlib.Path(args[args.index("-o") + 1])
        if os.environ.get("MOCK_RECORDER") != "pending":
            time.sleep(.25)
            path.write_text("fake-video")
            pathlib.Path(str(path) + ".ts").write_text("first-frame")
        while True:
            time.sleep(.02)
elif name == "sleep":
    time.sleep(min(float(args[0]), .02))
elif name == "sudo":
    sys.exit(int(os.environ.get("MOCK_DNF_STATUS", "0")))
'''


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="niri-capture-test-", dir=ROOT / "tests")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "calls.jsonl"
        self.log.touch()
        for name in ("niri", "magick", "gpu-screen-recorder", "notify-send", "qs", "xdg-open", "sleep", "sudo"):
            file = self.bin / name
            file.write_text(f"#!{sys.executable}\n" + MOCK)
            file.chmod(0o755)
        self.runtime = self.base / "runtime"
        self.runtime.mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin", HOME=str(self.base), XDG_RUNTIME_DIR=str(self.runtime), MOCK_LOG=str(self.log), MOCK_CAPTURE_PATH=str(self.base / "capture-path"))
        self.fast_clock = self.base / "bash-env"
        self.fast_clock.write_text('sleep() { local selected; if [[ "$MOCK_CAPTURE" == deferred ]]; then SECONDS=$((SECONDS + 11)); IFS= read -r selected < "$MOCK_CAPTURE_PATH" || true; printf complete-image > "$selected"; else SECONDS=$((SECONDS + 121)); fi; }\n')

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def run_script(self, script, *args, **env):
        return subprocess.run(["bash", str(QS / "scripts" / script), *map(str, args)], env=self.env | env, input="\n", capture_output=True, text=True, timeout=15)

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.02)
        self.fail("Timed out waiting for mocked recording state")

    def launch_recorder(self, **env):
        # Only the mock binary can be launched, never the installed recorder.
        proc = subprocess.Popen(["bash", str(QS / "scripts/screen_record.sh"), "start", "quickshell", "mic"], env=self.env | env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def cleanup():
            if proc.poll() is None:
                self.run_script("screen_record.sh", "stop", "quickshell")
                try:
                    proc.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.communicate()
        self.addCleanup(cleanup)
        return proc

    def test_native_screenshot_paths_and_no_focus_mutation(self):
        output = self.base / "space and ' quote; $(touch BAD).png"
        result = self.run_script("niri_screenshot.sh", "monitor", output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_text(), "complete-image")
        actions = [call for call in self.calls() if call[0] == "niri"]
        self.assertEqual(len(actions), 1)
        self.assertEqual(actions[0][1:6], ["msg", "action", "screenshot-screen", "--show-pointer", "false"])
        self.assertFalse((self.base / "BAD").exists())
        self.assertFalse(list(self.base.glob(".niri-capture-*")))

    def test_screenshot_invalid_mode_relative_path_failure_and_timeout(self):
        self.assertNotEqual(self.run_script("niri_screenshot.sh", "monitor", "relative.png").returncode, 0)
        self.assertNotEqual(self.run_script("niri_screenshot.sh", "invalid", self.base / "wrong.png").returncode, 0)
        self.assertNotEqual(self.run_script("niri_screenshot.sh", "monitor", self.base / "error.png", MOCK_CAPTURE="error").returncode, 0)
        self.assertNotEqual(self.run_script("niri_screenshot.sh", "monitor", self.base / "incomplete.png", MOCK_CAPTURE="incomplete", BASH_ENV=str(self.fast_clock)).returncode, 0)
        self.assertFalse((self.base / "incomplete.png").exists())
        self.assertFalse(list(self.base.glob(".niri-capture-*")))

    def test_region_uses_only_interactive_selection_and_waits_beyond_ten_seconds(self):
        output = self.base / "selected only.png"
        result = self.run_script("niri_screenshot.sh", "region", output, MOCK_CAPTURE="deferred", BASH_ENV=str(self.fast_clock))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_text(), "complete-image")
        actions = [call for call in self.calls() if call[0] == "niri"]
        self.assertEqual(len(actions), 1)
        self.assertEqual(actions[0][1:6], ["msg", "action", "screenshot", "--show-pointer", "false"])
        self.assertNotIn("screenshot-screen", self.log.read_text())

    def test_region_cancellation_timeout_has_no_output_and_cleans_late_save_directory(self):
        result = self.run_script("niri_screenshot.sh", "region", self.base / "cancelled.png", MOCK_CAPTURE="incomplete", BASH_ENV=str(self.fast_clock))
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("cancelled or timed out", result.stderr)
        self.assertFalse((self.base / "cancelled.png").exists())
        self.assertFalse(Path((self.base / "capture-path").read_text()).parent.exists())
        self.assertNotIn("screenshot-screen", self.log.read_text())

    def test_recorder_rejects_explicit_region_and_unsupported_binary(self):
        self.assertEqual(self.run_script("screen_record.sh", "start", "1920x1080+0+0").returncode, 2)
        self.assertEqual(self.run_script("screen_record.sh", "start", MOCK_RECORDER="unsupported").returncode, 2)
        self.assertFalse(any(call[0] == "gpu-screen-recorder" and "-w" in call for call in self.calls()))
        self.assertFalse(any(call[:6] == ["qs", "ipc", "call", "data", "set", "isRecording"] and call[-1] == "true" for call in self.calls()))

    def test_portal_pending_is_not_recording_and_can_cancel(self):
        proc = self.launch_recorder(MOCK_RECORDER="pending")
        self.wait_for(lambda: any(call[0] == "gpu-screen-recorder" and "-w" in call for call in self.calls()))
        time.sleep(.1)
        status = self.run_script("screen_record.sh", "status")
        self.assertIn("Recording pending", status.stdout)
        self.assertNotIn('"isRecording", "true"', self.log.read_text())
        self.assertEqual(self.run_script("screen_record.sh", "stop", "quickshell").returncode, 0)
        output, error = proc.communicate(timeout=5)
        self.assertEqual(proc.returncode, 0, error)
        self.assertIn("Recording cancelled", output)

    def test_portal_first_frame_updates_shell_and_stop_cleans_state(self):
        proc = self.launch_recorder()
        self.wait_for(lambda: '"isRecording", "true"' in self.log.read_text())
        call = next(call for call in self.calls() if call[0] == "gpu-screen-recorder" and "-w" in call)
        self.assertEqual(call[call.index("-w") + 1], "portal")
        self.assertEqual(call[call.index("-a") + 1], "default_output|default_input")
        self.assertEqual(call[call.index("-restore-portal-session") + 1], "no")
        self.assertEqual(self.run_script("screen_record.sh", "start").returncode, 1)
        self.assertEqual(self.run_script("screen_record.sh", "stop", "quickshell").returncode, 0)
        output, error = proc.communicate(timeout=5)
        self.assertEqual(proc.returncode, 0, error)
        self.assertIn("Recording saved", output)
        self.assertFalse((self.runtime / "bnsplit-recording/process").exists())
        self.assertEqual([call[-1] for call in self.calls() if call[:6] == ["qs", "ipc", "call", "data", "set", "isRecording"]][-1], "false")

    def test_recorder_failure_preserves_status_without_false_started(self):
        proc = self.launch_recorder(MOCK_RECORDER="error")
        output, error = proc.communicate(timeout=5)
        self.assertEqual(proc.returncode, 13, error)
        self.assertIn("without success", output)
        self.assertNotIn('"isRecording", "true"', self.log.read_text())

    def test_dnf_update_retains_argv_and_transaction_exit_status(self):
        for status in (0, 23):
            result = self.run_script("system_update.sh", "pkg-one", "pkg two", MOCK_DNF_STATUS=str(status))
            self.assertEqual(result.returncode, status)
        sudo = [call for call in self.calls() if call[0] == "sudo"]
        self.assertEqual(sudo, [["sudo", "dnf", "upgrade", "--assumeyes", "--", "pkg-one", "pkg two"]] * 2)
        self.assertTrue(any(call[:6] == ["qs", "ipc", "call", "niri", "focusApp", "quickshell-system-update"] for call in self.calls()))

    def test_qml_color_conversion_and_native_selected_image_processing(self):
        script = r'''
const fs = require("fs"), assert = require("assert");
const base = process.argv[1];
const color = fs.readFileSync(base + "/services/ColorPickerService.qml", "utf8");
const body = color.slice(color.indexOf("let picked;"), color.indexOf("copyProcess.exec"));
function convert(text, format) {
  return new Function("text", "root", body + "return extracted;")(text, {_currentFormat: format});
}
assert.strictEqual(convert('{"rgb":[1,0.5,0]}', "hex"), "#ff8000");
assert.strictEqual(convert('{"rgb":[0,1,0.25]}', "rgb"), "0, 255, 64");
for (const input of ['null', '{}', 'invalid', '{"rgb":[-1,0,0]}', '{"rgb":[1,0]}', '{"rgb":"abc"}'])
  assert.strictEqual(convert(input, "hex"), undefined);
const source = fs.readFileSync(base + "/surfaces/capture/ScreenCapture.qml", "utf8");
assert(!fs.existsSync(base + "/surfaces/capture/SelectionWindow.qml"));
assert(!source.includes("screenshot-screen"));
assert(!source.includes("startCrop"));
function fn(name) {
  const start = source.indexOf("function " + name + "(");
  return source.slice(start, source.indexOf("\n    }", start) + 6).replace(/:\s*(int|string|void|real|bool)\b/g, "");
}
const Paths = {scripts: "/scripts", screenshotTempDir: "/temp", screenshotDir: "/pictures", lensScript: "/scripts/lens.sh"};
const FileUtils = {trimFileProtocol: s => s.replace(/^file:\/\//, "")};
const GlobalCache = {loadLockScreen: false}, GlobalStates = {showScreenCapture: false};
const captureProcess = {running: false}, processingProcess = {running: false};
const calls = [], successes = [];
const Quickshell = {execDetached: argv => calls.push(argv)};
const root = {handleScreenshotSuccess: path => successes.push(path)};
const load = name => new Function("root", "captureProcess", "processingProcess", "Paths", "FileUtils", "GlobalCache", "GlobalStates", "Quickshell", "generateFilename", "return (" + fn(name) + ");")(root, captureProcess, processingProcess, Paths, FileUtils, GlobalCache, GlobalStates, Quickshell, () => "selected.png");
const start = load("startRegionCapture"), finish = load("finishCapture");
for (const mode of ["snapshot", "ocr", "lens"]) {
  captureProcess.running = false;
  processingProcess.running = false;
  start(true, "", mode);
  assert.strictEqual(root.pendingScreenshotPath, "/temp/selected.png");
  assert.strictEqual(captureProcess.command[2], "region");
  finish(0);
  if (mode === "lens") assert.deepStrictEqual(processingProcess.command, ["bash", "/scripts/lens.sh", "/temp/selected.png"]);
  if (mode === "ocr") {
    assert.strictEqual(processingProcess.command.at(-1), "/temp/selected.png");
    assert(!processingProcess.command.join(" ").includes("magick"));
    assert(processingProcess.running);
  }
}
assert.deepStrictEqual(successes, ["/temp/selected.png"]);
captureProcess.running = processingProcess.running = false;
start(false, "/custom dir");
assert.strictEqual(root.pendingScreenshotPath, "/custom dir/selected.png");
finish(2);
assert.strictEqual(successes.length, 1);
assert.strictEqual(processingProcess.running, false);
assert.strictEqual(GlobalStates.showScreenCapture, false);
assert.strictEqual(calls.length, 0);
captureProcess.running = false;
start(false, "", "ocr");
finish(1);
assert.strictEqual(successes.length, 1);
assert.strictEqual(processingProcess.running, false);
assert.strictEqual(calls.length, 1);
captureProcess.running = false;
load("captureMonitor")("/explicit-monitor.png");
assert.strictEqual(captureProcess.command[2], "monitor");
'''
        result = subprocess.run(["node", "-e", script, str(QS)], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
