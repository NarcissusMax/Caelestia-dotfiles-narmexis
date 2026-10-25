# Serpantinum desktop snapshot

Current installed configuration and customized shell source, exported on
25 October 2026 from CachyOS with Hyprland 0.56.2 and Quickshell 0.3.2.
Serpantinum 2.3.0 is based on upstream revision `e0c1d79`.

## Contents

- `home/.config/hypr/`: active Lua configuration, HyprMod settings and shortcuts.
- `home/.config/serpantinum/`: shell settings and saved display profiles.
- `home/.local/share/serpantinum/`: complete installed QML/Python/shell source,
  launch commands, shaders, fonts and other bundled assets.
- `home/.local/bin/`: relative Serpantinum launcher links and the Hyprland session
  wrapper, with executable permissions preserved.
- `home/.local/state/serpantinum/qs_colors.json` and `qs_matugen_colors.json`:
  the current theme palette, rather than the rest of the runtime state.
- `home/.local/share/easyeffects/output/`: the current audio processing preset.
- `home/.config/qt6ct/` and `environment.d/`: the current Qt theme integration.
- `sessions/`: the installed Serpantinum Wayland login-session entry.
- `manifest.json`: SHA-256 checksums and relative symbolic-link targets.

The source includes the restored fullscreen/bar behavior, volume up to 150%,
output-device filtering, playback-speed controls and the native Sound / Display
panel opened by **Super + M**. Each numeric display control has **−5% / +5%**
buttons and its own **Default …** reset button. Profiles, monitor selection,
enable/disable and live compositor changes share the same persistent backend.

See [DISPLAY.md](home/.local/share/serpantinum/src/quickshell/media/DISPLAY.md)
for exact ranges, units, implementation, checks and Wayland limitations.

## Restore

This snapshot is a backup of a working desktop, including monitor-specific
settings for the owner's laptop. Review the monitor output, scaling, application
commands and `/home/narmexis` paths before restoring on another account/machine.
The original installation remains the best place to install the distribution
dependencies before applying this snapshot.

From this directory, preview the file changes:

```sh
rsync -ani home/ "$HOME/"
```

Apply the reviewed snapshot, keeping copies of replaced files:

```sh
rsync -ai --backup --suffix=.before-serpantinum-20261025 home/ "$HOME/"
```

The snapshot contains only the listed shell files. Browser profiles, credential
stores, clipboard/history caches, runtime sockets and IP-geolocation cache are
not part of the export. The installed dangling `src/version.txt` link is exported
as the recorded `2.3.0` version string. The running machine's files are unchanged.

Start or reload the shell using the existing launch commands:

```sh
serpantinumd start
qs -p "$HOME/.local/share/serpantinum/src/quickshell/Shell.qml" ipc call main forceReload
```

The session desktop entry under `sessions/` can be installed separately into
`/usr/share/wayland-sessions/`. Review its account-specific `Exec` path first.
The wrapper launches Hyprland with `~/.config/hypr/hyprland.lua` through UWSM.

## Dependencies and checks

The restored system uses Hyprland, Quickshell/Qt 6, Python 3, Bash, jq, PipeWire,
WirePlumber, playerctl, Easy Effects, brightnessctl, qt6ct and UWSM. Other shell
features retain their upstream tool requirements. The display backend itself
uses Python's standard library and Hyprland's shader API; it starts no additional
gamma service.

Run the isolated display tests with:

```sh
python3 -m unittest discover \
  -s home/.local/share/serpantinum/src/quickshell/media/tests -v
```

Twelve tests cover actual GLES pixel transforms, profile persistence, input
validation, external-shader protection and reset. Live checks on the original
desktop also verified Super + M, slider output, ±5% buttons, individual reset,
profile editing and shell reloads. Physical multi-monitor hotplug and a fresh
login/reboot were not part of those checks.

## Upstream and license

This is a customized installed-source snapshot of
[ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum), not an independent
shell implementation. Upstream's GNU AGPL version 3 or later license is preserved
in [LICENSE.md](LICENSE.md), retrieved from the recorded base revision. Existing
upstream notices and bundled asset names are retained. The older Caelestia source
elsewhere in this repository keeps its own upstream license.
