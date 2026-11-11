# Known issues

## Open

### No place to change default applications

**Priority: low.** Default applications are set during installation, and changing them later needs a terminal and `xdg-mime`. The shell should offer a picker for links, video, images, PDF and text files.

### Icons sit slightly off center in their buttons

**Priority: low.** Nerd Font glyphs are wider than their advance and drawn off its center, for example 2.2 px to the right for the camera icon, so the hover background of an icon button looks shifted. Moving each glyph by its measured ink offset did not help visibly and was reverted.

### Installer looks stuck during post-install setup

**Priority: low, nice to have.** The setup script runs for several minutes on the "post-installation scripts" step, with no sign of what is happening, so the installer looks frozen. To be decided after more important work. One option is to show the script's progress on a text console with `chvt`, which is untested with the Wayland-based installer. Another is to move large packages to `%packages`, so they appear on the progress bar.

### Laptop wakes up after suspend on command

**Priority: low. Cause unknown.** On the MacBook, suspending by command woke the laptop after 5-7 seconds, while suspending by closing the lid worked for hours. The keyboard and touchpad have wakeup enabled, so the main hypothesis is touch.

To check, run `sleep 5; systemctl suspend` and keep your hands off the laptop for about 30 seconds. If it stays asleep, touch is the cause, and a `udev` rule can disable wakeup for those devices.

### One-off `br-connection-key-missing` from Bluetooth

**Priority: low. Cause unknown.** Earbuds returned this error once, and the next attempt succeeded. If it returns, save the `bluetoothd` logs from that moment.

## Limitations

- **Wired connections:** `Quickshell.Networking` knows only Wi-Fi, so a wired link is not shown on the bar.
- **Headset profiles:** the panel does not switch between A2DP and HFP, so a headset microphone can need a manual profile change.
- **Enterprise and WEP networks:** the panel points to `nmcli` or `nmtui`.
- **Notifications:** inline replies are not supported. History and Do Not Disturb do not survive a shell restart.
- **`make dev`:** only one program can own the notification service, so notifications go to the session's own shell. Wi-Fi, Bluetooth, audio and brightness act on the real hardware.
