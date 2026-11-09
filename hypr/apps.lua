-- Default applications started by keybindings.

local rofi_themes = require("hypr.lib.paths").root .. "/configs/rofi/"

return {
    terminal = "alacritty",
    files = "thunar",
    launcher = "rofi -show drun -show-icons -theme " .. rofi_themes .. "app_launcher.rasi",
    clipboard = "cliphist list | rofi -dmenu -display-columns 2 -theme "
        .. rofi_themes
        .. "menu.rasi | cliphist decode | wl-copy",
}
