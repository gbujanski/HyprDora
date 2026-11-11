-- All default keybindings: { keys, action, description, options }.
-- To change one, list it in ~/.config/hypr/binds.lua; see docs/development.md.

local hardware = { locked = true, repeating = true }
local media = { locked = true }

-- stylua: ignore
return {
    -- Applications
    { "SUPER + T",              act.terminal,         "Terminal" },
    { "SUPER + E",              act.files,            "Files" },
    { "SUPER + B",              act.browser,          "Browser" },
    { "SUPER + SPACE",          act.launcher,         "App launcher" },
    { "SUPER + CTRL + V",       act.clipboard,        "Clipboard history" },
    { "SUPER + L",              act.lock,             "Lock" },

    -- Panels
    { "SUPER + A",              act.action_center,    "Action center" },
    { "SUPER + Escape",         act.power_menu,       "Power" },
    { "Print",                  act.capture,          "Screenshot and recording" },
    { "SUPER + minus",          act.capture,          "Screenshot and recording" },

    -- Windows
    { "SUPER + Q",              act.close,            "Close window" },
    { "SUPER + P",              act.pseudo,           "Pseudotile" },
    { "SUPER + J",              act.toggle_split,     "Toggle split" },
    { "SUPER + mouse:272",      act.drag,             "Move window",      { mouse = true } },
    { "SUPER + mouse:273",      act.resize,           "Resize window",    { mouse = true } },

    -- Focus
    { "SUPER + left",           act.focus_left,       "Focus left" },
    { "SUPER + right",          act.focus_right,      "Focus right" },
    { "SUPER + up",             act.focus_up,         "Focus up" },
    { "SUPER + down",           act.focus_down,       "Focus down" },

    -- Workspaces
    { "SUPER + 1",              act.workspace(1),     "Workspace 1" },
    { "SUPER + 2",              act.workspace(2),     "Workspace 2" },
    { "SUPER + 3",              act.workspace(3),     "Workspace 3" },
    { "SUPER + 4",              act.workspace(4),     "Workspace 4" },
    { "SUPER + 5",              act.workspace(5),     "Workspace 5" },
    { "SUPER + 6",              act.workspace(6),     "Workspace 6" },
    { "SUPER + 7",              act.workspace(7),     "Workspace 7" },
    { "SUPER + 8",              act.workspace(8),     "Workspace 8" },
    { "SUPER + 9",              act.workspace(9),     "Workspace 9" },
    { "SUPER + 0",              act.workspace(10),    "Workspace 10" },
    { "SUPER + mouse_down",     act.workspace("e+1"), "Next workspace" },
    { "SUPER + mouse_up",       act.workspace("e-1"), "Previous workspace" },
    { "SUPER + S",              act.special,          "Scratchpad" },

    -- Move window to workspace
    { "SUPER + SHIFT + 1",      act.move_to(1),       "Move to workspace 1" },
    { "SUPER + SHIFT + 2",      act.move_to(2),       "Move to workspace 2" },
    { "SUPER + SHIFT + 3",      act.move_to(3),       "Move to workspace 3" },
    { "SUPER + SHIFT + 4",      act.move_to(4),       "Move to workspace 4" },
    { "SUPER + SHIFT + 5",      act.move_to(5),       "Move to workspace 5" },
    { "SUPER + SHIFT + 6",      act.move_to(6),       "Move to workspace 6" },
    { "SUPER + SHIFT + 7",      act.move_to(7),       "Move to workspace 7" },
    { "SUPER + SHIFT + 8",      act.move_to(8),       "Move to workspace 8" },
    { "SUPER + SHIFT + 9",      act.move_to(9),       "Move to workspace 9" },
    { "SUPER + SHIFT + 0",      act.move_to(10),      "Move to workspace 10" },

    -- Hardware keys
    { "XF86AudioRaiseVolume",   act.volume_up,        "Volume up",        hardware },
    { "XF86AudioLowerVolume",   act.volume_down,      "Volume down",      hardware },
    { "XF86AudioMute",          act.mute,             "Mute",             hardware },
    { "XF86AudioMicMute",       act.mic_mute,         "Mute microphone",  hardware },
    { "XF86MonBrightnessUp",    act.brightness_up,    "Brightness up",    hardware },
    { "XF86MonBrightnessDown",  act.brightness_down,  "Brightness down",  hardware },
    { "XF86PowerOff",           act.power_press,      "Power off when held for 2 seconds", { locked = true } },
    { "XF86PowerOff",           act.power_release,    "Power button released", { locked = true, release = true } },

    -- Media keys
    { "XF86AudioNext",          act.media_next,       "Next track",       media },
    { "XF86AudioPrev",          act.media_previous,   "Previous track",   media },
    { "XF86AudioPlay",          act.media_toggle,     "Play or pause",    media },
    { "XF86AudioPause",         act.media_toggle,     "Play or pause",    media },
}
