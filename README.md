# Caelestia dotfiles snapshot

Snapshot of my Caelestia and Hyprland configuration before removing the Hyprland sessions.

- `.config/caelestia/`: user shell and display settings
- `.config/hypr/`: compositor configuration, including a Noctalia alternate entry point
- `.config/quickshell/caelestia/`: Caelestia shell files in use locally
- `.config/uwsm/` and supporting terminal, launcher, prompt, visualizer, and fish configs
- `.local/bin/qsdisplay` and `.local/bin/qsgamma`: local display controls referenced by the configuration
- `sessions/`: installed Hyprland login entries for reference

The original paths are preserved under `.config/`. Application profiles, credentials, caches, and runtime state are excluded. `qsgamma` is the local x86-64 executable because its source was not present on this machine. Caelestia shell files retain their upstream license in `.config/quickshell/caelestia/LICENSE`.
