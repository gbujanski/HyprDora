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
    -- Portals and the polkit agent need the environment set before graphical-session.target starts.
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        .. " && systemctl --user start hyprdora-session.target"
        .. " ; systemctl --user start hyprpolkitagent",
    "gnome-keyring-daemon --start --components=secrets",
    "wl-paste --type text --watch cliphist store",
    "wl-paste --type image --watch cliphist store",
    "hypridle" .. packaged_unless_user("hypridle.conf"),
    "hyprpaper" .. packaged_unless_user("hyprpaper.conf"),
}

hl.on("hyprland.start", function()
    hl.exec_cmd(paths.shell)
    if not paths.dev then
        for _, command in ipairs(session_only) do
            hl.exec_cmd(command)
        end
    end
end)
