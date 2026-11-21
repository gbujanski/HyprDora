# Hardware and platform quirks

Findings from testing on real hardware. Each one explains code that may otherwise look unnecessary.

## Wi-Fi

- `Quickshell.Networking` works on the proprietary `wl` driver: scanning, signal and saved networks.
- `WifiNetwork.connect()` does not accept a password, so new networks go through `shell/scripts/nm-connect.py`. The helper also reports the exact failure and deletes the profile after a failed attempt.
- A wrong password can produce a kernel warning from `net/wireless/sme.c` with `wl`. The connection recovers on its own.

## Camera and suspend

- The FaceTime HD camera in the MacBook Air 7,2 (`14e4:1570`) has no driver in Fedora. `akmod-facetimehd` from the `mulderje/facetimehd-kmod` COPR builds one, and `facetimehd-firmware` downloads the firmware from Apple's driver package during installation. Verified on the MacBook: `/dev/video0` at 1280x720 streams frames.
- The FaceTime HD driver (`facetimehd`, an akmod from COPR) must not be in the initramfs. An initramfs rebuilt on the running system takes every loaded driver, but not the calibration files this one reads at start, so the camera starts half set up (`Direct firmware load for facetimehd/1871_01XX.dat failed`) and the next suspend never wakes: the log ends at `PM: suspend entry (deep)`. `/usr/lib/dracut/dracut.conf.d/90-hyprdora.conf` leaves it out, so it loads from the disk after the root is mounted. `pm_trace` pointed at a memory block, a false match, and did not help here.

## Bluetooth

- Quickshell does not register a pairing agent, so devices needing a PIN or code confirmation require `shell/scripts/bt-agent.py`.
- After pairing, BlueZ reports `Connected` for the bare link, before audio profiles start, and `BluetoothDevice.connect()` then refuses. The shell calls `Device1.Connect` directly, retrying on `busy` and `InProgress`.
- Right after power-on, BlueZ can reject discovery with "Resource Not Ready" and may later end it by itself. Discovery is retried while the page is open.

## Hyprland

- `WlrKeyboardFocus.Exclusive` makes Hyprland route all clicks to that layer, so panels use `OnDemand` to keep the bar clickable.
- `mirrorOf` in `hyprctl monitors` is a monitor id, not a name.
- `hl.monitor` merges with the existing rule, so a rule must state `disabled = false` and an empty `mirror` to re-enable a screen or stop mirroring.
- In Lua mode, `hyprctl keyword` and old `dispatch` syntax fail. Use `hyprctl eval` and `hyprctl dispatch 'hl.dsp...'`.
- Hyprland reloads the config when a file loaded with `require` changes, but not one loaded with `dofile`.
- A reload runs the whole config again, which drops rules applied with `hyprctl eval`.
- `hyprctl dispatch TEXT` runs `return hl.dispatch(TEXT)`, so text placed inside it must stay an expression, and text from outside must be a quoted Lua string it cannot leave (see `Launcher.luaString`).
- If both `hyprland.lua` and `hyprland.conf` exist, `hyprland.lua` is used.

## Monitors

- Saved rules use `desc:` selectors, because connector names can change.
- The laptop screen is always saved as enabled, so booting without an external monitor cannot give a black screen. "External only" therefore lasts until the session ends.
- A watchdog outside the shell reverts a monitor change if the shell dies before it is confirmed.

## Power and backlight

- UPower's aggregate device has no health data. It comes from the physical battery.
- `udev` does not report keyboard backlight changes, so the brightness file is watched with inotify, through `EventSources`.

## Audio

- Playback streams have `isSink == true`, so nodes are recognized by `PwNodeType`.

## Notifications

- `expireTimeout` is in milliseconds, and -1 means the default.

## Quickshell

- `console.log` is hidden by default. Use `console.info` or `console.warn`.
- A singleton is created on first use, so its `IpcHandler` does not exist until something references it.
- Devices and adapters appear asynchronously. The UI must react through bindings rather than read state once at startup.
- `FileView` with `preload: false` does not load the file after `reload()`.
- A QML property cannot start with `on` followed by a capital letter, because it is treated as a signal handler.
- Icons from a theme require an icon theme at start: `//@ pragma IconTheme` or `QS_ICON_THEME`, which `shell-start` sets from the settings; the pragma would win over the variable.
- In Quickshell 0.2.1, changing `timeout` on a running `IdleMonitor` has no effect until `enabled` is turned off and on again, so `services/Idle.qml` does that whenever a timeout changes. Verified in a nested Hyprland.
- A live config reload does not pick up a newly added QML file, such as a new singleton: references to it are undefined until the shell restarts. `make install` therefore restarts the shell service.
- `FileView.watchChanges` follows a file through being replaced, removed and made again, but not a file missing when the watch starts, and deleting the file's folder ends the watch for good. The owners of watched files therefore make them when missing, and make them again after a deletion, which also starts a new watch.
- `FileView.setText` writes in the background and does not emit `saved`; with `blockWrites: true` the file exists as soon as `setText` returns.
- Making an object from a `Component` while another object from the same component is still being made fails without a word. `EventSources` therefore attaches a stream's dependency with `Qt.callLater`.
- Properties given when an object is made can change, and emit their change signals, before the owner's handlers listen. `ScheduledTask` therefore acts only after `Component.onCompleted`.
- `PamContext` gives PAM's errors, such as an account locked by `pam_faillock`, as plain messages with `messageIsError` false. The lock screen keeps every line before the password prompt and shows them after a refusal.
- `qs ipc call` treats a function named `show` as its own subcommand, so no IPC function has that name.
- With `QT_QUICK_BACKEND=software`, which would save about 55 MB, the shell crashes as soon as a `ScreencopyView` appears (the window overview), and `ClippingRectangle` draws nothing, since it uses a shader.
- Processes the shell starts outlive it, because its service keeps child processes across a restart (`KillMode=process`) for programs opened from the shell. Every background process therefore runs under `setpriv --pdeathsig TERM`.

## Privacy indicators

- Hyprland sends a `screencast` event for every screen capture, including the shell's own recording and a `grim` screenshot. The screen indicator therefore waits a second and ignores the shell's own recording.
- Browsers open the camera directly rather than through PipeWire, so the camera indicator watches `/dev/video*` being opened and closed with `inotifywait`, and asks `fuser` who holds it only then. A camera plugged in later is noticed through `udevadm monitor`, which restarts the watch.

## Input

- A touchpad sends dozens of scroll events per gesture, so month changes in the calendar have a minimum delay (`calendarScrollDelay`).

## polkit

- Flatpak's `app-update` action implies `runtime-install`, so a runtime installs without a password whenever updates do, whatever a rule says about `runtime-install` itself.
- `pkcheck` and the D-Bus call report `polkit.result=auth_admin_keep` for an action that is nonetheless allowed through an implying action; only a check of every implying action shows why.
