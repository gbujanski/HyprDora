# Testing

There are no automated tests. Qt's test tools do not work with a `qs` shell without workarounds.

Changes are checked with `make lint`, `Hyprland --verify-config` for the Lua config, and by hand.

## Manual checklist

Run through the sections related to a change.

**Bar:** workspaces switch on click and scroll; the tray works; a bar appears and disappears with each monitor.

**Action center and calendar:** the bar icon, shortcut, Esc and a click outside all close the panel; bar icons stay clickable while it is open.

**Audio:** volume, mute, default output and input, per-application volume.

**Wi-Fi:** on/off, connect to saved and new networks, wrong password message, forget, hidden network.

**Bluetooth:** on/off, pair with a code, connect, audio output appears, forget.

**Notifications:** toasts with actions and images, history, Do Not Disturb with a critical notification.

**OSD and power:** volume, brightness and microphone indicators; lock, suspend; confirmations for logout, restart and power off.

**Displays (external monitor needed):** presets, drag to arrange, 15-second automatic revert, Keep and Revert, unplugging the active screen, layout survives a new session.

**Battery and brightness:** low and critical warnings; 0% stays readable; keys and slider agree.

**Weather and calendar:** hidden without a location; appears after setting one; month scrolling on a touchpad.

**Languages:** `language` set to `en` and `pl`; dates and day names follow it; a long Polish string does not break a layout.
