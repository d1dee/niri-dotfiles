#!/usr/bin/env python3
"""Validated niri include writer and opaque workspace-ID IPC adapter."""

import contextlib
import fcntl
import json
import math
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import uuid

DEFAULT_APPEARANCE = dict(shadows=True, transparency=False, rounded=True, bigGaps=False)
TRANSFORMS = ("normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270")


def config_dir():
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "niri"


def atomic_write(path, text):
    fd, temporary = tempfile.mkstemp(prefix=".bnsplit-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextlib.contextmanager
def locked(directory):
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / ".bnsplit-settings.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def load_settings(directory):
    path = directory / ".bnsplit-settings.json"
    if path.exists():
        data = json.loads(path.read_text())
    else:
        data = {}
    return {"appearance": dict(DEFAULT_APPEARANCE, **data.get("appearance", {})), "outputs": data.get("outputs", [])}


def number(value, low, high, integer=False):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError("Expected a finite numeric setting")
    if not low <= value <= high or (integer and value != int(value)):
        raise ValueError("Numeric setting out of range")
    return int(value) if integer else value


def render_outputs(configs):
    if not isinstance(configs, list) or len(configs) > 64:
        raise ValueError("Expected an output list")
    result = ["// Managed by the shell display settings."]
    seen = set()
    for cfg in configs:
        name = cfg.get("name")
        if not isinstance(name, str) or not name or len(name) > 256 or any(ord(c) < 32 for c in name) or name in seen:
            raise ValueError("Invalid or duplicate output name")
        seen.add(name)
        if cfg.get("mirrorOf") not in (None, "", "none"):
            raise ValueError("niri does not support output mirroring")
        width = number(cfg["width"], 1, 65535, True)
        height = number(cfg["height"], 1, 65535, True)
        refresh = number(cfg["refreshRate"], 1, 1000)
        scale = number(cfg["scale"], 0.1, 10)
        x = number(cfg["x"], -(2**31), 2**31 - 1, True)
        y = number(cfg["y"], -(2**31), 2**31 - 1, True)
        transform = number(cfg.get("transform", 0), 0, 7, True)
        disabled = cfg.get("disabled", False)
        if not isinstance(disabled, bool):
            raise ValueError("Invalid disabled setting")
        # JSON string escaping is a safe subset of KDL strings for these printable names.
        result.extend([f"output {json.dumps(name, ensure_ascii=False)} {{",
                       f'    mode "{width}x{height}@{refresh}"', f"    scale {scale}",
                       f'    transform "{TRANSFORMS[transform]}"', f"    position x={x} y={y}"])
        if disabled:
            result.append("    off")
        result.append("}")
    return "\n".join(result) + "\n"


def render_appearance(data):
    if set(data) != set(DEFAULT_APPEARANCE) or any(type(v) is not bool for v in data.values()):
        raise ValueError("Invalid appearance settings")
    return ("// Managed by the shell appearance settings.\nlayout {\n"
            f"    gaps {24 if data['bigGaps'] else 8}\n}}\nwindow-rule {{\n"
            f"    geometry-corner-radius {12 if data['rounded'] else 0}\n"
            f"    clip-to-geometry {'true' if data['rounded'] else 'false'}\n"
            f"    opacity {0.9 if data['transparency'] else 1.0}\n"
            f"    shadow {{\n        {'on' if data['shadows'] else 'off'}\n    }}\n}}\n")


def validated_write(directory, filename, content):
    # Validate the generated include AND the complete staged user config before touching live files.
    with tempfile.TemporaryDirectory(prefix="bnsplit-niri-") as temporary:
        staged = Path(temporary) / "niri"
        shutil.copytree(directory, staged, ignore=shutil.ignore_patterns(".bnsplit-*"))
        (staged / filename).write_text(content)
        for path in (staged / filename, staged / "config.kdl"):
            checked = subprocess.run(["niri", "validate", "-c", str(path)], capture_output=True, text=True, timeout=15)
            if checked.returncode:
                raise ValueError(checked.stderr.strip() or checked.stdout.strip() or "niri validation failed")
    atomic_write(directory / filename, content)


def save_settings(directory, data):
    atomic_write(directory / ".bnsplit-settings.json", json.dumps(data, indent=2) + "\n")


def ipc_request(request):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(3)
        connection.connect(os.environ["NIRI_SOCKET"])
        connection.sendall(json.dumps(request).encode() + b"\n")
        with connection.makefile("rb") as response:
            reply = json.loads(response.readline(1024 * 1024))
        if "Err" in reply:
            raise ValueError(reply["Err"])
        return reply["Ok"]


def finish_outputs(directory, token, keep):
    path = directory / ".bnsplit-pending.json"
    if not path.exists():
        return False
    pending = json.loads(path.read_text())
    if pending["token"] != token:
        return False
    if keep and pending["deadline"] <= time.time():
        finish_outputs(directory, token, False)
        raise ValueError("Display confirmation expired; changes reverted")
    if not keep:
        validated_write(directory, "outputs.kdl", pending["previous"])
        data = load_settings(directory)
        data["outputs"] = pending["outputs"]
        save_settings(directory, data)
    path.unlink()
    return True


def emit(value):
    print(json.dumps(value), flush=True)


def main(argv):
    command = argv[0]
    if command == "focus-workspace":
        workspace_id = int(argv[1])
        if workspace_id < 0:
            raise ValueError("Invalid workspace ID")
        ipc_request({"Action": {"FocusWorkspace": {"reference": {"Id": workspace_id}}}})
        return
    directory = config_dir()
    with locked(directory):
        data = load_settings(directory)
        pending_path = directory / ".bnsplit-pending.json"
        if command == "get":
            if pending_path.exists():
                pending = json.loads(pending_path.read_text())
                # A fresh shell must not inherit an unconfirmed display change from a crashed one.
                finish_outputs(directory, pending["token"], False)
                data = load_settings(directory)
            emit(data)
        elif command == "appearance":
            if argv[1] not in DEFAULT_APPEARANCE or argv[2] not in ("true", "false"):
                raise ValueError("Unknown appearance setting")
            data["appearance"][argv[1]] = argv[2] == "true"
            previous = (directory / "appearance.kdl").read_text()
            validated_write(directory, "appearance.kdl", render_appearance(data["appearance"]))
            try:
                save_settings(directory, data)
            except Exception:
                atomic_write(directory / "appearance.kdl", previous)
                raise
            emit(data)
        elif command == "outputs":
            if pending_path.exists():
                raise ValueError("A display change is already awaiting confirmation")
            configs = json.loads(argv[1])
            names = json.loads(argv[2])
            # Preserve saved settings for disconnected and unchanged outputs.
            changed = [c for c in configs if c.get("name") in names]
            merged = [c for c in data["outputs"] if c.get("name") not in names] + changed
            content = render_outputs(merged)
            if merged and all(c.get("disabled", False) for c in configs):
                raise ValueError("At least one connected output must remain enabled")
            token = uuid.uuid4().hex
            previous = (directory / "outputs.kdl").read_text()
            pending = dict(token=token, previous=previous, outputs=data["outputs"], deadline=time.time() + 12)
            # Journal before replacing, so a shell/helper crash can recover the old include.
            atomic_write(pending_path, json.dumps(pending))
            try:
                validated_write(directory, "outputs.kdl", content)
                data["outputs"] = merged
                save_settings(directory, data)
            except Exception:
                # Nothing is committed if validation failed; restore the exact previous include.
                atomic_write(directory / "outputs.kdl", previous)
                data["outputs"] = pending["outputs"]
                save_settings(directory, data)
                pending_path.unlink()
                raise
            emit(dict(status="applied", token=token))
        elif command in ("keep", "revert"):
            if not finish_outputs(directory, argv[1], command == "keep"):
                raise ValueError("Display confirmation expired or no longer matches")
            emit(dict(status="kept" if command == "keep" else "reverted"))
        else:
            raise ValueError("Unknown command")
    if command == "outputs":
        # Separate watchdog from the QML timer: expiry also works if the page disappears.
        while time.time() < pending["deadline"]:
            time.sleep(0.2)
            with locked(directory):
                if not pending_path.exists():
                    return
        with locked(directory):
            if finish_outputs(directory, token, False):
                emit(dict(status="reverted"))


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (ValueError, OSError, KeyError, IndexError, TypeError, subprocess.SubprocessError) as error:
        emit(dict(error=str(error)))
        sys.exit(1)
