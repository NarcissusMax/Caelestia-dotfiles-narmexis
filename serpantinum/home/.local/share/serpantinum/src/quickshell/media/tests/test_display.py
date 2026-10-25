"""Run: python3 -m unittest discover -s media/tests -v

The pixel tests execute the production GLSL with the system's GLES/EGL driver.
They neither change the desktop nor require Python packages or a running shell.
"""
import ctypes as C
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "display_backend.py"
spec = importlib.util.spec_from_file_location("display_backend", SOURCE)
display = importlib.util.module_from_spec(spec)
spec.loader.exec_module(display)


class GPU:
    def __init__(self):
        self.egl = C.CDLL("libEGL.so.1")
        self.gl = C.CDLL("libGLESv2.so.2")

        def bind(lib, name, result, *args):
            fn = getattr(lib, name)
            fn.restype, fn.argtypes = result, list(args)
            return fn

        ptr, uint, integer = C.c_void_p, C.c_uint, C.c_int
        bind(self.egl, "eglGetPlatformDisplay", ptr, uint, ptr, C.POINTER(integer))
        bind(self.egl, "eglInitialize", uint, ptr, C.POINTER(integer), C.POINTER(integer))
        bind(self.egl, "eglBindAPI", uint, uint)
        bind(self.egl, "eglChooseConfig", uint, ptr, C.POINTER(integer), C.POINTER(ptr), integer, C.POINTER(integer))
        bind(self.egl, "eglCreatePbufferSurface", ptr, ptr, ptr, C.POINTER(integer))
        bind(self.egl, "eglCreateContext", ptr, ptr, ptr, ptr, C.POINTER(integer))
        bind(self.egl, "eglMakeCurrent", uint, ptr, ptr, ptr, ptr)
        bind(self.egl, "eglTerminate", uint, ptr)
        self.dpy = self.egl.eglGetPlatformDisplay(0x31DD, None, None)
        major, minor = integer(), integer()
        if not self.egl.eglInitialize(self.dpy, C.byref(major), C.byref(minor)):
            raise RuntimeError("Surfaceless EGL initialization failed")
        assert self.egl.eglBindAPI(0x30A0)
        config, count = ptr(), integer()
        attrs = (integer * 13)(0x3033, 1, 0x3040, 0x40, 0x3024, 8, 0x3023, 8, 0x3022, 8, 0x3021, 8, 0x3038)
        assert self.egl.eglChooseConfig(self.dpy, attrs, C.byref(config), 1, C.byref(count)) and count.value
        surface = self.egl.eglCreatePbufferSurface(self.dpy, config, (integer * 5)(0x3057, 1, 0x3056, 1, 0x3038))
        context = self.egl.eglCreateContext(self.dpy, config, None, (integer * 3)(0x3098, 3, 0x3038))
        assert surface and context and self.egl.eglMakeCurrent(self.dpy, surface, surface, context)

        for name, result, args in [
            ("glCreateShader", uint, [uint]),
            ("glShaderSource", None, [uint, integer, C.POINTER(C.c_char_p), ptr]),
            ("glCompileShader", None, [uint]),
            ("glGetShaderiv", None, [uint, uint, C.POINTER(integer)]),
            ("glGetShaderInfoLog", None, [uint, integer, ptr, ptr]),
            ("glCreateProgram", uint, []),
            ("glAttachShader", None, [uint, uint]),
            ("glLinkProgram", None, [uint]),
            ("glGetProgramiv", None, [uint, uint, C.POINTER(integer)]),
            ("glUseProgram", None, [uint]),
            ("glDeleteProgram", None, [uint]),
            ("glDeleteShader", None, [uint]),
            ("glGetUniformLocation", integer, [uint, C.c_char_p]),
            ("glUniform1i", None, [integer, integer]),
            ("glGenTextures", None, [integer, C.POINTER(uint)]),
            ("glBindTexture", None, [uint, uint]),
            ("glTexParameteri", None, [uint, uint, integer]),
            ("glTexImage2D", None, [uint, integer, integer, integer, integer, integer, uint, uint, ptr]),
            ("glViewport", None, [integer, integer, integer, integer]),
            ("glDrawArrays", None, [uint, integer, integer]),
            ("glReadPixels", None, [integer, integer, integer, integer, uint, uint, ptr]),
            ("glGetError", uint, []),
        ]:
            bind(self.gl, name, result, *args)
        texture = uint()
        self.gl.glGenTextures(1, C.byref(texture))
        self.gl.glBindTexture(0x0DE1, texture)
        self.gl.glTexParameteri(0x0DE1, 0x2801, 0x2600)
        self.gl.glTexParameteri(0x0DE1, 0x2800, 0x2600)
        self.gl.glViewport(0, 0, 1, 1)

    def compile(self, kind, source):
        shader = self.gl.glCreateShader(kind)
        text = C.c_char_p(source.encode())
        self.gl.glShaderSource(shader, 1, C.byref(text), None)
        self.gl.glCompileShader(shader)
        okay = C.c_int()
        self.gl.glGetShaderiv(shader, 0x8B81, C.byref(okay))
        if not okay.value:
            log = C.create_string_buffer(8192)
            self.gl.glGetShaderInfoLog(shader, 8192, None, log)
            raise AssertionError(log.value.decode())
        return shader

    def pixel(self, values, output=0, pixel=(102, 153, 204, 255), other=None):
        monitors = [{"id": 0, "name": "panel"}, {"id": 7, "name": "external"}]
        entries = {"panel": {"enabled": True, "values": display.validate(values)}}
        if other:
            entries["external"] = {"enabled": True, "values": display.validate(other)}
        fragment = display.shader_for(monitors, entries)
        vert = self.compile(0x8B31, """#version 300 es
out vec2 v_texcoord;
void main() {
    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
    v_texcoord = p;
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}"""
        )
        frag = self.compile(0x8B30, fragment)
        program = self.gl.glCreateProgram()
        self.gl.glAttachShader(program, vert)
        self.gl.glAttachShader(program, frag)
        self.gl.glLinkProgram(program)
        okay = C.c_int()
        self.gl.glGetProgramiv(program, 0x8B82, C.byref(okay))
        assert okay.value, "Shader link failed"
        self.gl.glUseProgram(program)
        self.gl.glUniform1i(self.gl.glGetUniformLocation(program, b"wl_output"), output)
        self.gl.glUniform1i(self.gl.glGetUniformLocation(program, b"tex"), 0)
        self.gl.glTexImage2D(0x0DE1, 0, 0x1908, 1, 1, 0, 0x1908, 0x1401, (C.c_ubyte * 4)(*pixel))
        self.gl.glDrawArrays(0x0004, 0, 3)
        result = (C.c_ubyte * 4)()
        self.gl.glReadPixels(0, 0, 1, 1, 0x1908, 0x1401, result)
        assert self.gl.glGetError() == 0, "GPU rendering error"
        self.gl.glDeleteProgram(program)
        self.gl.glDeleteShader(vert)
        self.gl.glDeleteShader(frag)
        return tuple(result)


class Pixels(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gpu = GPU()

    @classmethod
    def tearDownClass(cls):
        cls.gpu.egl.eglTerminate(cls.gpu.dpy)

    def test_identity_is_exact(self):
        self.assertEqual(self.gpu.pixel({}), (102, 153, 204, 255))

    def test_every_slider_changes_real_pixels(self):
        baseline = self.gpu.pixel({})
        for key, control in display.CONTROLS.items():
            bound = control[1] if control[1] != control[2] else control[0]
            with self.subTest(control=key):
                result = self.gpu.pixel({key: bound})
                self.assertGreater(max(abs(a - b) for a, b in zip(result, baseline)), 2)

    def test_grayscale_has_equal_channels(self):
        rgb = self.gpu.pixel({"grayscale": True})[:3]
        self.assertLessEqual(max(rgb) - min(rgb), 1)

    def test_inversion_and_gamma_direction(self):
        self.assertEqual(self.gpu.pixel({"invert": True}), (153, 102, 51, 255))
        result = self.gpu.pixel({"gamma": 1.5})
        self.assertTrue(all(a > b for a, b in zip(result[:3], (102, 153, 204))))

    def test_warm_cool_and_blue_filter(self):
        warm = self.gpu.pixel({"temperature": 3500})
        cool = self.gpu.pixel({"temperature": 9500})
        blue = self.gpu.pixel({"blueLight": 50})
        self.assertLess(warm[2], 204)
        self.assertLess(cool[0], 102)
        self.assertLess(blue[2], 110)

    def test_monitor_routing_and_unaffected_output(self):
        self.assertEqual(self.gpu.pixel({"invert": True}, output=12), (102, 153, 204, 255))
        self.assertEqual(self.gpu.pixel({"grayscale": True}, output=7, other={"invert": True}), (153, 102, 51, 255))

    def test_extremes_are_finite_and_all_presets_compile(self):
        for name, values in display.PRESETS.items():
            with self.subTest(profile=name):
                result = self.gpu.pixel(values)
                self.assertEqual(result[3], 255)
        for bound in (0, 1):
            self.gpu.pixel({k: v[bound] for k, v in display.CONTROLS.items()} | {"invert": True})


class Profiles(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {"XDG_CONFIG_HOME": self.temp.name, "XDG_RUNTIME_DIR": self.temp.name})
        self.env.start()
        self.backend = display.Backend()
        self.backend.monitors = [{"name": "panel", "id": 0}]
        self.backend.state["monitors"]["panel"] = {"enabled": False, "profile": "Default", "values": dict(display.DEFAULTS)}
        self.backend.apply = lambda *args, **kwargs: None

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def call(self, **kwargs):
        return self.backend.handle({"monitor": "panel", **kwargs})

    def test_profile_lifecycle_and_reload(self):
        self.call(op="preset", profile="Warm")
        self.call(op="save", name="My evening")
        self.call(op="rename", profile="My evening", name="Evening")
        reloaded = display.Backend()
        self.assertEqual(reloaded.state["monitors"]["panel"]["profile"], "Evening")
        self.assertEqual(reloaded.state["profiles"]["Evening"]["temperature"], 4500)
        self.call(op="delete", profile="Evening")
        self.assertEqual(self.backend.state["monitors"]["panel"]["values"]["temperature"], 4500)
        self.call(op="reset")
        self.assertEqual(self.backend.state["monitors"]["panel"]["values"], display.DEFAULTS)
        self.assertFalse(self.backend.state["monitors"]["panel"]["enabled"])

    def test_invalid_values_names_and_absent_monitors_preserve_state(self):
        before = json.dumps(self.backend.state, sort_keys=True)
        for request in [dict(op="set", values={"gamma": 0}), dict(op="set", values={"hue": float("nan")}),
                        dict(op="save", name="Default"), dict(op="save", name=""),
                        dict(op="set", monitor="missing", values={"brightness": 50})]:
            self.assertTrue(self.call(**request)["error"])
            self.assertEqual(json.dumps(self.backend.state, sort_keys=True), before)

    def test_corrupt_config_is_preserved(self):
        self.backend.config.parent.mkdir(parents=True, exist_ok=True)
        self.backend.config.write_text("broken json")
        with self.assertRaises(ValueError):
            display.Backend()
        self.assertEqual(self.backend.config.read_text(), "broken json")

    def test_scanout_and_shader_return_to_original_state(self):
        compositor = {"shader": "", "scanout": 2}
        self.backend.apply = display.Backend.apply.__get__(self.backend)
        self.backend.current_shader = lambda: compositor["shader"]
        self.backend.set_shader = lambda value: compositor.update(shader=value)
        self.backend.set_scanout = lambda value: compositor.update(scanout=value)
        self.backend.hypr = lambda *args, **kwargs: {"int": compositor["scanout"]}
        entry = self.backend.state["monitors"]["panel"]
        entry["enabled"] = True
        entry["values"]["brightness"] = 90
        self.backend.apply()
        self.assertEqual(compositor["scanout"], 0)
        self.assertTrue(self.backend.owns_shader(compositor["shader"]))
        entry["enabled"] = False
        self.backend.apply()
        self.assertEqual(compositor, {"shader": "", "scanout": 2})
        self.assertFalse(self.backend.lease_path.exists())

    def test_existing_external_shader_is_never_overwritten(self):
        self.backend.apply = display.Backend.apply.__get__(self.backend)
        self.backend.current_shader = lambda: "/existing/custom.frag"
        self.backend.set_shader = lambda _: self.fail("External shader was overwritten")
        entry = self.backend.state["monitors"]["panel"]
        entry["enabled"] = True
        entry["values"]["brightness"] = 90
        with self.assertRaisesRegex(RuntimeError, "Another screen shader"):
            self.backend.apply()


if __name__ == "__main__":
    unittest.main()
