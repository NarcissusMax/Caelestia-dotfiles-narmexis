#!/usr/bin/env python3
"""Serpantinum display transforms for Hyprland 0.56+; standard library only.

One shell-owned process, one compositor shader, no gamma-ramp daemon. Commands
are newline-delimited JSON on stdin or the private session socket. State is
atomically saved separately from upstream shell settings.
"""
from __future__ import annotations

import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import selectors
import signal
import socket
import subprocess
import sys
import time


# min, max, default, step, label, unit; shared verbatim with the QML interface.
CONTROLS = {
    "brightness": (20, 150, 100, 1, "Brightness", "%"),
    "contrast": (25, 200, 100, 1, "Contrast", "%"),
    "saturation": (0, 200, 100, 1, "Saturation", "%"),
    "gamma": (0.4, 2.5, 1, 0.01, "Gamma", ""),
    "temperature": (2500, 10000, 6500, 50, "Temperature", " K"),
    "blueLight": (0, 80, 0, 1, "Blue light filter", "%"),
    "hue": (-180, 180, 0, 1, "Hue", "°"),
    "red": (0, 200, 100, 1, "Red gain", "%"),
    "green": (0, 200, 100, 1, "Green gain", "%"),
    "blue": (0, 200, 100, 1, "Blue gain", "%"),
    "redGamma": (0.4, 2.5, 1, 0.01, "Red gamma", ""),
    "greenGamma": (0.4, 2.5, 1, 0.01, "Green gamma", ""),
    "blueGamma": (0.4, 2.5, 1, 0.01, "Blue gamma", ""),
    "blackLevel": (0, 30, 0, 1, "Black level", "%"),
    "whiteLevel": (70, 100, 100, 1, "White level", "%"),
    "shadows": (-50, 50, 0, 1, "Shadows", "%"),
    "highlights": (-50, 50, 0, 1, "Highlights", "%"),
}
DEFAULTS = {k: v[2] for k, v in CONTROLS.items()} | {"grayscale": False, "invert": False}
PRESETS = {
    "Default": {},
    "Vibrant": {"saturation": 125, "contrast": 106},
    "Cinematic": {"saturation": 88, "contrast": 115, "gamma": 0.95, "temperature": 6000},
    "High Contrast": {"contrast": 135, "saturation": 105},
    "Warm": {"temperature": 4500},
    "Cool": {"temperature": 8500},
    "Night": {"temperature": 3200, "brightness": 65, "blueLight": 25},
    "Reading": {"temperature": 4800, "brightness": 85, "saturation": 75, "contrast": 95},
    "Grayscale": {"grayscale": True},
}


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    with temp.open("w") as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, path)


def read_json(path, fallback):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return copy.deepcopy(fallback)


def validate(values):
    result = dict(DEFAULTS)
    for key, value in values.items():
        if key in ("grayscale", "invert"):
            if not isinstance(value, bool):
                raise ValueError(f"{key} must be true or false")
            result[key] = value
        elif key in CONTROLS:
            lo, hi, _, step, *_ = CONTROLS[key]
            value = float(value)
            if not math.isfinite(value) or not lo <= value <= hi:
                raise ValueError(f"{key} must be between {lo} and {hi}")
            result[key] = round(round(value / step) * step, 4)
        else:
            raise ValueError(f"Unknown adjustment: {key}")
    return result


def temperature_rgb(kelvin):
    # Approximate Planckian white point, normalized so 6500 K is exact identity.
    def rgb(k):
        t = k / 100.0
        return [255 if t <= 66 else 329.698727446 * (t - 60) ** -0.1332047592,
                99.4708025861 * math.log(t) - 161.1195681661 if t <= 66 else 288.1221695283 * (t - 60) ** -0.0755148492,
                255 if t >= 66 else (0 if t <= 19 else 138.5177312231 * math.log(t - 10) - 305.0447927307)]
    ref = rgb(6500)
    return [min(1.0, max(0.0, c / r)) for c, r in zip(rgb(kelvin), ref)]


def f(value):
    return f"{float(value):.7f}"


def shader_for(monitors, entries):
    """Generate one pointwise GLES 3 transform; retain normal damage tracking."""
    parts = ["""#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform int wl_output;
vec3 hueRotate(vec3 c, float angle) {
    // YIQ rotation keeps the achromatic axis fixed.
    float y = dot(c, vec3(0.299, 0.587, 0.114));
    float i = dot(c, vec3(0.596, -0.274, -0.322));
    float q = dot(c, vec3(0.211, -0.523, 0.312));
    float co = cos(angle), si = sin(angle);
    float ii = i * co - q * si, qq = i * si + q * co;
    return vec3(y + 0.956 * ii + 0.621 * qq,
                y - 0.272 * ii - 0.647 * qq,
                y - 1.106 * ii + 1.703 * qq);
}
void main() {
    vec4 source = texture(tex, v_texcoord);
    vec3 c = source.rgb;
    fragColor = source;
"""
    ]
    for monitor in monitors:
        entry = entries.get(monitor["name"], {})
        v = entry.get("values", DEFAULTS)
        if not entry.get("enabled") or v == DEFAULTS:
            continue
        parts.append(f"    if (wl_output == {int(monitor['id'])}) {{\n")
        if v["blackLevel"] or v["whiteLevel"] != 100:
            black, white = v["blackLevel"] / 100, v["whiteLevel"] / 100
            parts.append(f"        c = clamp((c - {f(black)}) / {f(white - black)}, 0.0, 1.0);\n")
        if v["shadows"] or v["highlights"]:
            parts.append(f"        c += {f(v['shadows'] / 100)} * c * pow(vec3(1.0) - c, vec3(2.0)) * 4.0\n"
                         f"           + {f(v['highlights'] / 100)} * c * c * (vec3(1.0) - c) * 4.0;\n")
        if v["contrast"] != 100:
            parts.append(f"        c = (c - 0.5) * {f(v['contrast'] / 100)} + 0.5;\n")
        if v["hue"]:
            parts.append(f"        c = hueRotate(c, {f(math.radians(v['hue']))});\n")
        saturation = 0 if v["grayscale"] else v["saturation"] / 100
        if saturation != 1:
            parts.append(f"        c = mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, {f(saturation)});\n")
        gammas = [v["gamma"] * v[k] for k in ("redGamma", "greenGamma", "blueGamma")]
        if any(g != 1 for g in gammas):
            parts.append("        c = pow(clamp(c, 0.0, 1.0), vec3(" + ", ".join(f(1 / g) for g in gammas) + "));\n")
        gains = temperature_rgb(v["temperature"])
        gains = [g * v[k] / 100 * v["brightness"] / 100 for g, k in zip(gains, ("red", "green", "blue"))]
        gains[1] *= 1 - v["blueLight"] / 100 * 0.12
        gains[2] *= 1 - v["blueLight"] / 100
        if any(abs(g - 1) > 1e-7 for g in gains):
            parts.append("        c *= vec3(" + ", ".join(f(g) for g in gains) + ");\n")
        if v["invert"]:
            parts.append("        c = vec3(1.0) - clamp(c, 0.0, 1.0);\n")
        parts.append("        fragColor = vec4(clamp(c, 0.0, 1.0), source.a);\n        return;\n    }\n")
    parts.append("}\n")
    return "".join(parts)


class Backend:
    def __init__(self):
        self.config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "serpantinum/display-profiles.json"
        self.runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "serpantinum-display"
        self.runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
        signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "unavailable")
        self.session = hashlib.sha256(signature.encode()).hexdigest()[:12]
        self.socket_path = self.runtime / f"{self.session}.sock"
        self.lease_path = self.runtime / f"{self.session}.json"
        self.state = (json.loads(self.config.read_text()) if self.config.exists()
                      else {"version": 1, "monitors": {}, "profiles": {}})
        if not isinstance(self.state, dict) or self.state.get("version") != 1:
            raise ValueError("Unsupported display profile file; original file was preserved")
        self.state.setdefault("monitors", {})
        self.state.setdefault("profiles", {})
        for entry in self.state["monitors"].values():
            entry["values"] = validate(entry.get("values", {}))
        for name, values in self.state["profiles"].items():
            self.state["profiles"][name] = validate(values)
        self.monitors = []
        self.error = ""
        self.warning = ""
        self.applied = False
        self.revision = 0
        self.save_at = 0
        self.last_source = None
        self.slot = 0
        self.lease = read_json(self.lease_path, {})

    @staticmethod
    def hypr(*args, json_result=False):
        proc = subprocess.run(["hyprctl", *( ["-j"] if json_result else []), *args],
                              capture_output=True, text=True, timeout=4)
        if proc.returncode:
            raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "Hyprland is unavailable")
        if json_result:
            return json.loads(proc.stdout)
        if proc.stdout.strip() != "ok":
            raise RuntimeError(proc.stdout.strip())
        return proc.stdout

    def current_shader(self):
        value = self.hypr("getoption", "decoration:screen_shader", json_result=True).get("str", "")
        return "" if value == "[[EMPTY]]" else value

    def owns_shader(self, path):
        return path in [str(self.runtime / f"{self.session}-{i}.frag") for i in (0, 1)]

    def set_shader(self, path):
        # Since 0.55, Lua configurations reject `hyprctl keyword` even though
        # getoption still works. Use the live configuration API on this system.
        try:
            self.hypr("eval", "hl.config({decoration={screen_shader=" + json.dumps(path) + "}})")
        except RuntimeError as exc:
            if "eval is only supported" not in str(exc):
                raise
            self.hypr("keyword", "decoration:screen_shader", path or "[[EMPTY]]")

    def set_scanout(self, value):
        try:
            self.hypr("eval", "hl.config({render={direct_scanout=" + str(int(value)) + "}})")
        except RuntimeError as exc:
            if "eval is only supported" not in str(exc):
                raise
            self.hypr("keyword", "render:direct_scanout", str(int(value)))

    def refresh(self):
        self.monitors = [m for m in self.hypr("monitors", json_result=True) if not m.get("disabled")]
        for monitor in self.monitors:
            self.state["monitors"].setdefault(monitor["name"], {
                "enabled": False, "profile": "Default", "values": dict(DEFAULTS)})
        shell_settings = read_json(self.config.parent / "settings.json", {})
        display = shell_settings.get("display", {})
        legacy = display.get("enabled", False) or any(m.get("enabled") for m in display.get("monitors", {}).values())
        self.warning = ("The existing Night Light is enabled in shell settings; its gamma adjustment also affects the output. Disable it there to use this panel alone."
                        if legacy else "")
        for monitor in self.monitors:
            if monitor.get("colorManagementPreset") in ("hdr", "hdredid"):
                self.warning = "HDR is active. These artistic SDR transforms can clip HDR highlights; use Default for accurate HDR."

    def snapshot(self):
        return {"ready": True, "monitors": [{"name": m["name"], "description": m.get("description", m["name"]),
                "id": m["id"], "focused": m.get("focused", False)} for m in self.monitors],
                "settings": self.state["monitors"], "profiles": list(PRESETS) + list(self.state["profiles"]),
                "customProfiles": list(self.state["profiles"]), "controls": CONTROLS,
                "defaults": DEFAULTS, "error": self.error, "warning": self.warning,
                "applied": self.applied, "revision": self.revision}

    def apply(self, force=False):
        effective = [m for m in self.monitors if self.state["monitors"][m["name"]]["enabled"]
                     and self.state["monitors"][m["name"]]["values"] != DEFAULTS]
        current = self.current_shader()
        if not effective:
            if self.owns_shader(current):
                self.set_shader(self.lease.get("previous", ""))
            if "scanout" in self.lease:
                current_scanout = self.hypr("getoption", "render:direct_scanout", json_result=True).get("int", 0)
                if current_scanout == 0 and self.lease["scanout"] != 0:
                    self.set_scanout(self.lease["scanout"])
            self.last_source = None
            self.applied = False
            self.lease = {}
            self.lease_path.unlink(missing_ok=True)
            return
        if current and not self.owns_shader(current):
            raise RuntimeError("Another screen shader is active. Disable it before enabling display adjustments.")
        if not self.lease:
            self.lease = {"previous": current if not self.owns_shader(current) else "",
                          "scanout": self.hypr("getoption", "render:direct_scanout", json_result=True).get("int", 0)}
            atomic_json(self.lease_path, self.lease)
        if self.hypr("getoption", "render:direct_scanout", json_result=True).get("int", 0) != 0:
            self.set_scanout(0)
        source = shader_for(self.monitors, self.state["monitors"])
        if source == self.last_source and self.owns_shader(current) and not force:
            return
        self.slot = 1 - self.slot
        target = self.runtime / f"{self.session}-{self.slot}.frag"
        temp = target.with_suffix(".tmp")
        temp.write_text(source)
        os.replace(temp, target)
        self.set_shader(str(target))
        if self.current_shader() != str(target):
            raise RuntimeError("Hyprland did not accept the display shader")
        self.last_source = source
        self.applied = True

    def handle(self, request):
        original = copy.deepcopy(self.state)
        try:
            op = request.get("op", "status")
            name = request.get("monitor", "")
            if op in ("status", "refresh"):
                if op == "refresh":
                    self.refresh()
                    self.apply()
                return self.snapshot()
            if name not in self.state["monitors"] or name not in [m["name"] for m in self.monitors]:
                raise ValueError("The selected monitor is no longer connected")
            entry = self.state["monitors"][name]
            if op == "set":
                patch = request.get("values", {})
                entry["values"] = validate(entry["values"] | patch)
                entry["profile"] = "Custom"
            elif op == "enable":
                if not isinstance(request["enabled"], bool):
                    raise ValueError("Enabled must be true or false")
                entry["enabled"] = request["enabled"]
            elif op == "preset":
                profile = request["profile"]
                if profile in PRESETS:
                    entry["values"] = validate(PRESETS[profile])
                elif profile in self.state["profiles"]:
                    entry["values"] = dict(self.state["profiles"][profile])
                else:
                    raise ValueError("Profile no longer exists")
                entry["profile"] = profile
                entry["enabled"] = profile != "Default"
            elif op == "reset":
                entry.update(enabled=False, profile="Default", values=dict(DEFAULTS))
            elif op in ("save", "rename", "delete"):
                profile = str(request.get("profile", "")).strip()
                if op in ("rename", "delete") and profile not in self.state["profiles"]:
                    raise ValueError("Only saved custom profiles can be renamed or deleted")
                new_name = str(request.get("name", "")).strip()
                if op != "delete":
                    if not new_name or len(new_name) > 48 or any(ord(c) < 32 for c in new_name):
                        raise ValueError("Use a profile name of 1–48 printable characters")
                    if new_name in PRESETS or new_name == "Custom" or (new_name in self.state["profiles"] and new_name != profile):
                        raise ValueError("That profile name is already in use")
                if op == "save":
                    self.state["profiles"][new_name] = dict(entry["values"])
                    entry["profile"] = new_name
                elif op == "rename":
                    self.state["profiles"][new_name] = self.state["profiles"].pop(profile)
                    for item in self.state["monitors"].values():
                        if item["profile"] == profile:
                            item["profile"] = new_name
                else:
                    del self.state["profiles"][profile]
                    for item in self.state["monitors"].values():
                        if item["profile"] == profile:
                            item["profile"] = "Custom"
            else:
                raise ValueError(f"Unknown operation: {op}")
            self.apply()
            self.error = ""
            self.revision += 1
            self.save_at = time.monotonic() + 0.4
            # Profile operations and resets survive even an immediate logout.
            if op != "set":
                self.save()
        except (ValueError, KeyError, TypeError, OSError, RuntimeError, subprocess.SubprocessError) as exc:
            self.state = original
            self.error = str(exc)
            try:
                self.apply()
            except (OSError, RuntimeError, subprocess.SubprocessError):
                pass
        return self.snapshot()

    def save(self):
        atomic_json(self.config, self.state)
        self.save_at = 0


def serve():
    backend = Backend()
    lock = (backend.runtime / f"{backend.session}.lock").open("w")
    # A hot reload can start the replacement just before the old QML Process exits.
    end = time.monotonic() + 4
    while True:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() >= end:
                raise RuntimeError("A display controller is already running for this session")
            time.sleep(0.05)
    # The predecessor may have flushed a final slider movement while we waited.
    backend = Backend()
    backend.socket_path.unlink(missing_ok=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(backend.socket_path))
    os.chmod(backend.socket_path, 0o600)
    server.listen(8)
    server.setblocking(False)
    sel = selectors.DefaultSelector()
    sel.register(server, selectors.EVENT_READ, "accept")
    sel.register(sys.stdin, selectors.EVENT_READ, "stdin")
    buffers = {sys.stdin: b""}
    events = None
    event_buffer = b""
    refresh_at = 0
    running = True

    def stop(*_):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def publish():
        try:
            print(json.dumps(backend.snapshot(), ensure_ascii=False), flush=True)
        except BrokenPipeError:
            stop()

    def connect_events():
        nonlocal events
        signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        events.connect(str(Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")) / "hypr" / signature / ".socket2.sock"))
        events.setblocking(False)
        sel.register(events, selectors.EVENT_READ, "events")

    try:
        try:
            backend.refresh()
            backend.apply(force=True)
            connect_events()
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
            backend.error = str(exc)
        publish()
        while running:
            now = time.monotonic()
            deadlines = [t for t in (backend.save_at, refresh_at) if t]
            timeout = max(0, min(deadlines) - now) if deadlines else 1.0
            for key, _ in sel.select(min(timeout, 1.0)):
                stream = key.fileobj
                if key.data == "accept":
                    client, _ = server.accept()
                    client.setblocking(False)
                    buffers[client] = b""
                    sel.register(client, selectors.EVENT_READ, "client")
                    continue
                data = os.read(stream.fileno(), 65536)
                if not data:
                    if stream is sys.stdin or stream is events:
                        running = False
                    else:
                        sel.unregister(stream)
                        buffers.pop(stream, None)
                        stream.close()
                    continue
                if key.data == "events":
                    event_buffer += data
                    while b"\n" in event_buffer:
                        line, event_buffer = event_buffer.split(b"\n", 1)
                        if line.startswith((b"monitoradded", b"monitorremoved", b"configreloaded")):
                            refresh_at = time.monotonic() + 0.25
                    continue
                buffers[stream] += data
                if len(buffers[stream]) > 65536:
                    buffers[stream] = b""
                    continue
                while b"\n" in buffers[stream]:
                    line, buffers[stream] = buffers[stream].split(b"\n", 1)
                    try:
                        request = json.loads(line)
                        if not isinstance(request, dict):
                            raise ValueError("Expected a JSON object")
                        reply = backend.handle(request)
                    except (ValueError, TypeError) as exc:
                        backend.error = str(exc)
                        reply = backend.snapshot()
                    if key.data == "client":
                        try:
                            stream.sendall((json.dumps(reply) + "\n").encode())
                        except OSError:
                            pass
                    publish()
            now = time.monotonic()
            if backend.save_at and now >= backend.save_at:
                try:
                    backend.save()
                except OSError as exc:
                    backend.error = f"Could not save display settings: {exc}"
                    backend.save_at = 0
                    publish()
            if refresh_at and now >= refresh_at:
                refresh_at = 0
                try:
                    backend.refresh()
                    backend.apply(force=True)
                    backend.error = ""
                except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
                    backend.error = str(exc)
                publish()
    finally:
        if backend.save_at:
            backend.save()
        backend.socket_path.unlink(missing_ok=True)
        sel.close()
        server.close()
        # Leave the transform in place across shell reloads; the session lease
        # lets the replacement controller reclaim it without a color flash.


def client(request):
    backend = Backend()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(6)
        connection.connect(str(backend.socket_path))
        connection.sendall((json.dumps(request) + "\n").encode())
        response = b""
        while b"\n" not in response:
            chunk = connection.recv(65536)
            if not chunk:
                raise RuntimeError("Display controller closed the connection")
            response += chunk
        return json.loads(response.split(b"\n", 1)[0])


if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "serve":
            serve()
        else:
            request = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {"op": "status"}
            result = client(request)
            print(json.dumps(result, indent=2, ensure_ascii=False))
            sys.exit(1 if result.get("error") else 0)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps({"ready": False, "error": str(error)}), flush=True)
        sys.exit(1)
