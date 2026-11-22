-- Keyboard, pointer and touchpad defaults. The shell writes the user's choices to input.lua in the user's
-- Hyprland directory, which loads after this file.

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Gestures are listed by hand in the shell's shortcut list (services/Shortcuts.qml); keep the two in step.
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- As on a Mac: three fingers up show the windows and workspaces (Mission Control), and pinching the thumb
-- and three fingers together opens the launcher (Launchpad). Hyprland names directions as a zoom does:
-- "pinchout" is fingers coming together, "pinchin" spreading them, as tried on the MacBook's touchpad.
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd(require("hypr.lib.paths").shell .. " ipc call panel toggle overview")
    end,
})

hl.gesture({
    fingers = 4,
    direction = "pinchout",
    action = function()
        hl.exec_cmd(require("hypr.lib.paths").shell .. " ipc call panel launcher apps")
    end,
})
