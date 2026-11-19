-- Named actions available in keybinding files as `act`.

local apps = require("hypr.apps")
local paths = require("hypr.lib.paths")

local exec = hl.dsp.exec_cmd

---Builds an action that calls a function of the shell through IPC.
---@param call string IPC target, function and arguments
---@return string command shell command
local function shell_call(call)
    return paths.shell .. " ipc call " .. call
end

return {
    exec = exec,

    terminal = exec(apps.terminal),
    files = exec(apps.files),
    browser = exec(apps.browser),
    launcher = exec(shell_call("launcher toggle")),
    overview = exec(shell_call("overview toggle")),
    clipboard = exec(shell_call("launcher clipboard")),
    lock = exec("loginctl lock-session"),

    action_center = exec(shell_call("actioncenter toggle")),
    power_menu = exec(shell_call("powermenu toggle")),
    power_press = exec(shell_call("powerbutton press")),
    power_release = exec(shell_call("powerbutton release")),
    capture = exec(shell_call("capture toggle")),

    close = hl.dsp.window.close(),
    pseudo = hl.dsp.window.pseudo(),
    toggle_split = hl.dsp.layout("togglesplit"),
    drag = hl.dsp.window.drag(),
    resize = hl.dsp.window.resize(),

    focus_left = hl.dsp.focus({ direction = "left" }),
    focus_right = hl.dsp.focus({ direction = "right" }),
    focus_up = hl.dsp.focus({ direction = "up" }),
    focus_down = hl.dsp.focus({ direction = "down" }),

    ---@param id integer|string workspace
    workspace = function(id)
        return hl.dsp.focus({ workspace = id })
    end,
    ---@param id integer|string workspace
    move_to = function(id)
        return hl.dsp.window.move({ workspace = id })
    end,
    special = hl.dsp.workspace.toggle_special("magic"),

    -- Through the shell, which shows the indicator for them; wpctl is a fallback for when it is not running.
    volume_up = exec(shell_call("audio stepVolume 0.05") .. " || wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    volume_down = exec(shell_call("audio stepVolume -0.05") .. " || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    mute = exec(shell_call("audio toggleMute") .. " || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    mic_mute = exec(shell_call("audio toggleMicrophone") .. " || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),

    -- brightnessctl is a fallback for when the shell is not running.
    brightness_up = exec(shell_call("brightness step 0.05") .. " || brightnessctl -e4 -n2 set 5%+"),
    brightness_down = exec(shell_call("brightness step -0.05") .. " || brightnessctl -e4 -n2 set 5%-"),
    keyboard_light_up = exec(
        shell_call("brightness stepKeyboard 0.1") .. " || brightnessctl -d '*::kbd_backlight' set 10%+"
    ),
    keyboard_light_down = exec(
        shell_call("brightness stepKeyboard -0.1") .. " || brightnessctl -d '*::kbd_backlight' set 10%-"
    ),

    media_next = exec("playerctl next"),
    media_previous = exec("playerctl previous"),
    media_toggle = exec("playerctl play-pause"),
}
