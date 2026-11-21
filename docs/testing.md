# Testing

There are no automated tests. Qt's test tools do not work with a `qs` shell without workarounds.

Changes are checked with `make lint`, `Hyprland --verify-config` for the Lua config, a nested session for the shell, and by hand.

## Nested test runner

`tools/nested-test.sh` starts a nested Hyprland with the shell from the repository, runs a short bash file against it, and closes it. The real session is not touched: the nested one has its own config folder and Wayland socket. A run takes a few seconds.

```bash
cat > /tmp/sound.sh <<'EOF'
q panel open sound; sleep 1.5
grim "$T/shots/sound.png"
W -k Escape; sleep 1
echo "open after Esc: '$(q panel current)'"
EOF
tools/nested-test.sh sound /tmp/sound.sh
```

In the test file, `q` calls the nested shell's IPC, `W` types or presses keys with `wtype` (unpacked into `build/`, not installed), and `$T` is the result folder, `build/test/NAME`, with its `config/`, `shots/` and the nested Hyprland's log. Errors from the shell's log are printed at the end. `SETTINGS=~/.config/hyprdora/settings.json` starts with real settings, such as a weather location; `EMPTY_CONFIG=1` starts without config folders, as on a new account. A third argument runs another copy of the shell.

A second, virtual screen is added with `hyprctl output create headless`. Wi-Fi, Bluetooth, sound, drives and brightness act on the real hardware, and notifications go to the session's own shell, which owns the notification service.

## Manual checklist

Run through the sections related to a change.

**Bar:** workspaces switch on click and scroll; the clock with the weather opens the calendar; the bell, and the media button while something plays, sit next to it; the tray works; status icons open their panels (sound, battery, drives, displays with an external screen, updates); the logo on the right opens the action center and turns green while it is open; a bar appears and disappears with each monitor.

**Panels:** the bar icon, shortcut, Esc and a click outside all close a panel; bar icons stay clickable while one is open; only one panel is open at a time.

**Sound:** the speaker opens the sound panel with both sections unfolded; in the action center they start folded; volume, mute, readable device names (speakers, headphones after plugging into the jack, Bluetooth name), the volume of each application.

**Wi-Fi:** on/off, connect to saved and new networks, wrong password message, forget, hidden network, metered setting.

**Bluetooth:** on/off, pair with a code, connect, audio output appears, forget.

**VPN:** import a WireGuard or OpenVPN file, connect, disconnect, traffic counters.

**Drives:** a USB stick and an SD card appear with their partitions; open, safely remove (the drive powers off), a program holding a file is named; a BitLocker partition unlocks with its password.

**Notifications:** toasts with actions and images, history in the panel under the bell (also after a shell restart), Do Not Disturb with a critical notification; opening the panel ends the toasts on screen, and a notification arriving while it is open shows only in its list; toasts wait while the action center is open.

**OSD and power:** volume, brightness and microphone indicators only for one's own changes; lock, suspend; confirmations for logout, restart and power off.

**Lock screen:** a wrong password flashes red; Caps Lock turns the prompt amber; `/help` and its commands; after ten wrong passwords (installed from the ISO) the reason shows under the prompt.

**Administrator prompt:** a `pkexec` command and a software install show the prompt; a wrong password says so; Esc cancels.

**Displays (external monitor needed):** the bar icon appears; presets, drag to a corner and to the center of an edge, 15-second automatic revert, Keep and Revert, unplugging the active screen, layout survives a new session.

**Battery and brightness:** low and critical warnings; 0% stays readable; keys and slider agree; power profiles from the battery panel.

**Updates:** the bar icon appears with updates; the panel lists them with sizes; installing at restart shows the update screen with counts and progress, then restarts.

**System restore:** the settings category lists snapshots after the password; taking a snapshot; restoring one restarts into it.

**Capture:** `Print`, the `SUPER` shortcut and the action center button open it; area, full screen and window; the overlay is not in the result; the screenshot reaches the clipboard; Edit opens `swappy`; recording shows the bar indicator, stops cleanly and the file plays; hardware encoding is used where available.

**Launcher:** applications by name, without diacritics and with typos; arithmetic such as `2*(3+4)` shows its result; `>` runs a command; web search; the clipboard history searches, pastes and deletes an entry.

**Window overview:** windows of every workspace with live thumbnails; click to focus; drag to another workspace.

**Weather and calendar:** hidden without a location; appears after setting one; month scrolling on a touchpad; events of a Nextcloud account and of the offline calendar; adding an event with reminders and repeats; a reminder arrives; deleting one occurrence or the whole series.

**Online accounts:** adding a Nextcloud account opens the browser and finishes after approval; an `http://` address is refused; signing out revokes the app password.

**Languages:** `language` set to `en` and `pl`; dates and day names follow it; a long Polish string does not break a layout.
