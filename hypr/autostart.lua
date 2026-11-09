-- Programs started with the session.

local paths = require("hypr.lib.paths")

-- A nested session must not start a second copy of these, because they act on the real one.
local session_only = {
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "gnome-keyring-daemon --start --components=secrets",
    "systemctl --user start hyprpolkitagent",
    "wl-paste --type text --watch cliphist store",
    "wl-paste --type image --watch cliphist store",
    "hypridle",
    "hyprpaper",
}

hl.on("hyprland.start", function()
    hl.exec_cmd(paths.shell)
    if not paths.dev then
        for _, command in ipairs(session_only) do
            hl.exec_cmd(command)
        end
    end
end)
