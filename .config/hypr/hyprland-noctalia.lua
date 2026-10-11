-- Select Noctalia, then load the existing Hyprland configuration unchanged.
_G.HYPR_SHELL_SESSION = "noctalia"
dofile(os.getenv("HOME") .. "/.config/hypr/hyprland.lua")
