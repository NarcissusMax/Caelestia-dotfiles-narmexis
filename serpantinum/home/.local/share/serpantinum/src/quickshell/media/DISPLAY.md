# Sound / Display panel

Installed for Serpantinum / Quickshell 0.3.2 on Hyprland 0.56.2, 25 October 2026.
The running shell is Serpantinum, rather than Noctalia. Integration therefore
extends the actual `media/MusicPopup.qml` opened by the existing Super + M
binding. No Hyprland configuration, keybinding, audio backend or theme settings
were replaced.

## Use

Press **Super + M**, then select **Display**. Select a preset to enable its
adjustments immediately, or turn on the master switch and move the sliders.
Switching the master off retains your adjustments. **Default** or **Reset**
restores neutral output for the selected monitor and turns its adjustments off.
When every connected monitor is neutral/off, the compositor shader is removed.

The monitor buttons appear when more than one output is connected. Each output
has its own enabled flag, selected profile and values. Disconnected outputs keep
their settings. All controls show their current value, bounds and neutral value.
Each slider has **−5%** and **+5%** buttons beside its value. Percentage settings
move by five percentage points; gamma, temperature and hue move by 5% of their
slider range, rounded to the nearest supported step. Values stop at the slider
limits, where the corresponding button is disabled. Button changes apply live
when the master switch is on and are saved through the same profile system.
The **Default …** button beneath each slider resets only that adjustment to its
neutral value. It applies immediately when enabled, preserves all other values
and the master switch, and is disabled when that adjustment is already neutral.

Use **Advanced adjustments** for hue, RGB gains, individual RGB gamma, black and
white input levels, shadows and highlights. Scroll within the controls to reach
the complete advanced section. Presets remain available at the bottom.

**Save as…** creates a named snapshot of the current values. Select a saved
profile to apply it; **Rename** and **Delete** appear for saved custom profiles.
Deleting a profile preserves the current output as Custom. Built-in presets
cannot be renamed/deleted. Profile names must be unique and 1–48 characters.
The profile list scrolls when necessary, so adding profiles does not resize the
panel.

Sound retains the existing player, playback speed, equalizer, audio and lyrics
controls. Its cover is slightly smaller to accommodate the shared navigation.
The panel remains 625 × 645 at its existing position. Ctrl + Tab switches the
top-level section; Tab/Shift + Tab retain their previous meaning in Sound and
navigate controls in Display. Sliders support arrow keys and Home/End.

## Actual output adjustments

One GLES 3 screen shader implements all 17 sliders plus grayscale and inversion.
The shader transforms final desktop pixel output and routes each monitor's
settings using Hyprland's `wl_output` uniform. Temperature uses an approximate
Planckian white point, with 6500 K defined as neutral. Blue light filtering
attenuates blue and, slightly, green. Shadows and highlights apply bounded tonal
curves. These are artistic adjustments, not measured monitor calibration.

Brightness changes pixel output, not the panel backlight. Increasing it can clip
highlights; dimming it does not save backlight power. Black/white levels are input
levels; moving black up clips dark detail, while moving white down clips bright
detail. High contrast/saturation, combined gamma adjustments and inversion can
also clip colors. This is expected for bounded SDR transforms.

This does not restyle website backgrounds/text, provide per-application CSS, or
implement Midnight Lizard's website-specific rules. No browser extension is
required. Hardware cursors can bypass the screen shader. Screen captures may be
taken before the final shader and may therefore omit its effect. HDR transforms
are not calibrated; Default is recommended for accurate HDR.

The existing shell Night Light is left intact. If it is enabled, the Display tab
reports that its gamma correction also affects output. Turn it off in the
existing display settings when using this panel's temperature/filter controls.
No second gamma-ramp service, Hyprsunset or wl-gammarelay process is started.
An unrelated active screen shader blocks activation with a visible error; it is
never overwritten. Direct scanout is temporarily disabled while effects are
active so fullscreen clients cannot bypass the transform; its previous value is
restored when effects are removed.

Hyprland's native screen shader API and output ID routing were verified against
the installed release's [OpenGL implementation](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/render/OpenGL.cpp).
This system uses the [Lua runtime configuration API](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/)
through `hyprctl eval`; `keyword` is only a fallback for legacy configurations.

## Persistence and runtime

Settings: `~/.config/serpantinum/display-profiles.json`.
This file is separate from the existing shell settings and is written atomically.
Slider saves are batched, with a final flush on normal process shutdown.
Profiles, presets, enable/disable and reset are saved immediately. A malformed
profile file is preserved and reported instead of being silently overwritten.

The shell starts `DisplayService`, which owns one Python controller process
(about 20 MB resident in this session). Its lifetime follows the shell; it is not
a separate enabled systemd service. A per-session lock prevents duplicates.
The controller listens for monitor changes and compositor config reloads using
Hyprland's event socket. Output IDs are rebuilt on hotplug. A runtime lease keeps
the transform in place across shell reloads and records the original shader and
direct-scanout state. Only two generated shader files are retained per session.

Preview writes are limited to ten per second. Each enabled, non-neutral output
uses a single pointwise shader pass without a time uniform or disabled damage
tracking. Neutral/default output has no extra shader pass. No Python packages or
new runtime dependencies are needed: Python 3, Hyprland, Qt and Quickshell were
already installed. GLES/EGL and glslang were used for verification.

## Files

Created:

- `media/DisplayView.qml`
- `media/DisplaySlider.qml`
- `media/display_backend.py`
- `media/tests/test_display.py`
- `media/DISPLAY.md`
- `singletons/environment/DisplayService.qml`
- `~/.config/serpantinum/display-profiles.json`

Modified:

- `media/MusicPopup.qml`: segmented navigation and same-size content sections.
- `media/qmldir`, `qmldir`: component/singleton registration.
- `Shell.qml`: start the display controller with the session.
- `reusables/inputs/SliderProgress.qml`: add its missing theme-singleton import.

Original modified files are backed up in
`~/.local/state/serpantinum-customizations/display-panel/`.
Shell updates can overwrite local source changes; retain that backup and these
new files when upgrading Serpantinum.

## Reload and recovery

The running shell has already been reloaded. For a later manual reload:

```bash
qs -p "$HOME/.local/share/serpantinum/src/quickshell/Shell.qml" ipc call main forceReload
```

Open directly in Display:

```bash
serpantinum msg open music display
```

If an extreme setting makes the panel hard to read, reset the laptop output:

```bash
python3 "$HOME/.local/share/serpantinum/src/quickshell/media/display_backend.py" \
  '{"op":"reset","monitor":"eDP-1"}'
```

For emergency removal when the controller is unavailable:

```bash
hyprctl eval 'hl.config({decoration={screen_shader=""}})'
```

Then correct the profile settings before restarting the shell; otherwise the
saved profile will be restored normally. The emergency command alone does not
modify saved profiles.

## Verification

- Qt 6 QML lint passed. The new QML has no warnings/errors; the existing shell/panel
  still has upstream lint warnings about dynamic properties and aliases.
- Python syntax checks passed.
- 44 generated shader variants passed glslang validation: every slider's bounds,
  all presets, combined extremes and two monitor branches.
- Twelve automated tests passed. They render the production GLSL through GLES/EGL
  and verify every slider changes pixels, grayscale, inversion, gamma direction,
  warm/cool filtering, neutral identity and monitor routing. They also cover
  profile creation/rename/delete/reload, reset, invalid input, corrupt files,
  direct-scanout restoration and protection of an existing external shader.
- Live Hyprland accepted the generated shader; applying a preset changed the
  active shader setting. Reset removed it with no shader/configuration errors.
- Live save/rename/delete succeeded. The selected Warm custom profile and active
  shader survived a full Quickshell configuration reload; one controller process
  remained.
- Super + M was tested with uinput keyboard events and opened/closed the actual
  music panel. The original binding and script are unchanged.
- Sound and Display were inspected in the live session, including the advanced
  scroll area and inline profile editor. No additional window is used.
- Live pointer tests verified slider application and reset, as well as creating,
  renaming and deleting a custom profile through the actual interface.
- Ctrl + Tab was verified in the live panel. Shader files stayed unchanged while
  effects were enabled and idle, confirming there is no continuous recompilation.
- Multi-monitor shader routing is tested; physical monitor hotplug, a full reboot,
  and calibrated HDR output were not tested on this single-output session.

Rerun the isolated tests without altering the desktop:

```bash
python3 -m unittest discover \
  -s "$HOME/.local/share/serpantinum/src/quickshell/media/tests" -v
```
