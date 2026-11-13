-- Programs started with the session.

local paths = require("hypr.lib.paths")

---Returns the option that selects a config file, preferring the user's copy.
---@param name string config file name
---@return string option empty when the program finds the user's file by itself
local function packaged_unless_user(name)
    local file = io.open(paths.user_dir .. "/" .. name, "r")
    if file ~= nil then
        file:close()
        return ""
    end
    return " -c " .. paths.root .. "/configs/hypr/" .. name
end

-- A nested session must not start a second copy of these, because they act on the real one.
local session_only = {
    -- Portals, the polkit agent and the shell service need the environment set before
    -- graphical-session.target starts. The session target also starts the shell.
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
        .. " && systemctl --user start hyprdora-session.target"
        .. " ; systemctl --user start hyprpolkitagent",
    "gnome-keyring-daemon --start --components=secrets",
    "/usr/libexec/hyprdora/first-login.sh",
    "wl-paste --type text --watch cliphist store",
    "wl-paste --type image --watch cliphist store",
    "hypridle" .. packaged_unless_user("hypridle.conf"),
    "hyprpaper" .. packaged_unless_user("hyprpaper.conf"),
}

hl.on("hyprland.start", function()
    -- In a real session the shell runs as a service that restarts it after a crash.
    if paths.dev then
        -- Same as in the shell service: Qt's touchpad gesture handling crashes the shell.
        hl.exec_cmd("QT_WAYLAND_DISABLED_INTERFACES=zwp_pointer_gestures_v1 " .. paths.shell)
        return
    end
    for _, command in ipairs(session_only) do
        hl.exec_cmd(command)
    end
end)
