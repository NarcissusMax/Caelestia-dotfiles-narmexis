# Desktop dotfiles: Serpantinum and Hyprland

The current setup is saved in **[serpantinum/](serpantinum/)**, updated on
25 October 2026. It includes the installed Serpantinum 2.3.0 source, Hyprland Lua
configuration, theme colors, audio preset and login-session launcher.

**Super + M** opens the integrated Sound / Display panel. Display provides live
GPU color adjustments, per-monitor profiles, custom presets, ±5% buttons and an
individual reset button beneath every slider. Existing music, playback-speed,
equalizer and audio controls are included.

See [restore instructions and dependencies](serpantinum/README.md) and the
[display implementation notes](serpantinum/home/.local/share/serpantinum/src/quickshell/media/DISPLAY.md).

The older Caelestia snapshot below is retained for reference.

## Earlier Caelestia snapshot

Snapshot of my Caelestia and Hyprland configuration before removing the Hyprland sessions.

- `.config/caelestia/`: user shell and display settings
- `.config/hypr/`: compositor configuration, including a Noctalia alternate entry point
- `.config/quickshell/caelestia/`: Caelestia shell files in use locally
- `.config/uwsm/` and supporting terminal, launcher, prompt, visualizer, and fish configs
- `.local/bin/qsdisplay` and `.local/bin/qsgamma`: local display controls referenced by the configuration
- `sessions/`: installed Hyprland login entries for reference

The original paths are preserved under `.config/`. Application profiles, credentials, caches, and runtime state are excluded. `qsgamma` is the local x86-64 executable because its source was not present on this machine. Caelestia shell files retain their upstream license in `.config/quickshell/caelestia/LICENSE`.
