-- Keyboard, pointer and touchpad. The keyboard layout is set in the user's settings.lua.

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

-- Gestures are listed by hand in the shell's shortcut list (ShortcutsSettings.qml); keep the two in step.
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
