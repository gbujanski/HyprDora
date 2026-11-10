-- Window and layer rules.

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "system-tui-panels",
    match = { class = "^(sys.*)$" },
    float = true,
    size = "900 600",
    center = true,
    animation = "none",
})

-- OnlyOffice opens its file dialogs at 0,0, under the bar.
hl.window_rule({
    name = "center-onlyoffice-dialogs",
    match = { class = "^DesktopEditors$" },
    center = true,
})

-- An animated fade-out would appear in the capture.
hl.layer_rule({
    name = "capture-no-animation",
    match = { namespace = "^hyprdora-capture$" },
    no_anim = true,
})
