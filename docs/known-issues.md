# Known issues

## Open

### Icons sit slightly off center in their buttons

**Priority: low.** Nerd Font glyphs are wider than their advance and drawn off its center, for example 2.2 px to the right for the camera icon, so the hover background of an icon button looks shifted. Moving each glyph by its measured ink offset did not help visibly and was reverted.

### Installer looks stuck during post-install setup

**Priority: low, nice to have.** The setup script ran for several minutes on the "post-installation scripts" step, with no sign of what is happening, so the installer looked frozen. Most of that time went to Flatpaks, which setup no longer installs since applications moved to the welcome screen (2026-11-24); the next install will show whether the wait is still long. One option is to show the script's progress on a text console with `chvt`, which is untested with the Wayland-based installer. Another is to move large packages to `%packages`, so they appear on the progress bar.

### Laptop wakes up after suspend on command

**Priority: low. Cause unknown.** On the MacBook, suspending by command woke the laptop after 5-7 seconds, while suspending by closing the lid worked for hours. The keyboard and touchpad have wakeup enabled, so the main hypothesis is touch.

To check, run `sleep 5; systemctl suspend` and keep your hands off the laptop for about 30 seconds. If it stays asleep, touch is the cause, and a `udev` rule can disable wakeup for those devices.

### One-off `br-connection-key-missing` from Bluetooth

**Priority: low. Cause unknown.** Earbuds returned this error once, and the next attempt succeeded. If it returns, save the `bluetoothd` logs from that moment.

## Limitations

- **Fedora 45:** not supported yet; HyprDora is built for Fedora 44 only. A system upgraded to Fedora 45 gets no HyprDora updates, and one installed from the ISO cannot upgrade, as `hyprdora-release` 44 requires Fedora 44's repositories. Stay on Fedora 44, supported until 2027-05-19, until HyprDora supports 45.
- **Wired connections:** `Quickshell.Networking` knows only Wi-Fi, so the bar shows a wired link from `nmcli` and only as an icon, without settings. It has not been tested with a cable.
- **Headset profiles:** the panel does not switch between A2DP and HFP, so a headset microphone can need a manual profile change.
- **Enterprise and WEP networks:** the panel points to `nmcli` or `nmtui`.
- **OpenVPN with a login:** the shell cannot ask for a VPN password yet, so such a connection shows an error. Certificate-only OpenVPN and WireGuard work. OpenVPN has been tested only up to importing a file.
- **Notifications:** inline replies are not supported. Do Not Disturb turned on by hand does not survive a shell restart; one on a schedule comes back, and so does the history.
- **`make dev`:** only one program can own the notification service, so notifications go to the session's own shell. Wi-Fi, Bluetooth, audio and brightness act on the real hardware.
- **"Skipped OpenPGP checks" in the log of an update installed at restart:** expected. `dnf upgrade --offline` checks the signatures when it downloads the packages and stops on any problem; the install at boot then skips the check on purpose, and installs nothing if the system changed in between.
- **Lock screen and shell crashes:** the lock screen is part of the shell. If the shell stops while the screen is locked, the session ends and the login screen comes back, so unsaved work is lost. Hyprland never shows the desktop in between. If the shell is not running when a lock is requested, the screen does not lock.
- **Black background in a virtual machine without 3D:** hyprpaper crashes when it starts (in `hyprtoolkit`, while making its first buffer) on a virtual GPU without 3D acceleration, such as QEMU's plain `virtio` or VirtualBox without it, so the wallpaper stays black; the rest of the desktop works. With 3D acceleration (QEMU `-device virtio-vga-gl`, virgl) and on real hardware it draws the wallpaper. Seen on 2026-11-24 with hyprpaper 0.8.5.
- **Qt and touchpad gestures:** Qt 6.11 crashes when a touchpad swipe starts over a surface the program has just closed. The shell never needs Qt's gesture events, since Hyprland handles the gestures, so it runs with `QT_WAYLAND_DISABLED_INTERFACES=zwp_pointer_gestures_v1`. Other Qt applications can still hit it.
