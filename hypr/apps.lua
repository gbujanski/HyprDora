-- Default applications started by keybindings.

return {
    -- The default terminal and file manager, chosen in the shell's settings.
    terminal = "xdg-terminal-exec",
    files = [[sh -c 'gtk-launch "$(xdg-mime query default inode/directory)"']],
    -- The default browser, so changing it elsewhere also changes this shortcut.
    browser = [[sh -c 'gtk-launch "$(xdg-settings get default-web-browser)"']],
}
