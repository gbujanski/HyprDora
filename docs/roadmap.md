# Roadmap

Status: **accepted** · Created: 2026-11-08

The plan as accepted, and the record of the work since. Sections 2 and 3 show the repository and the system as first planned; the current state is described in [architecture](architecture.md) and [installation](installation.md).

## 1. Goals

- One product in one new repository with a fresh commit history. The old project is kept unchanged as `HyprDora-legacy`.
- A project to show on GitHub, not a distribution to promote.
- The installer is written from scratch. The shell is **moved** from GUI-demo, not rewritten, because it carries fixes found on real hardware.
- Three target machines: MacBook Air 7,2 (Intel, Broadcom `wl`), Lenovo Legion (Intel + NVIDIA), desktop with AMD. Drivers are detected automatically.
- The ISO **never wipes a disk on its own**. Partitioning and the user account are set in the installer; everything else is automatic.

## 2. Repository layout

```text
hyprdora/
├── shell/              # Quickshell shell (from GUI-demo)
│   ├── i18n/           # en.json, pl.json
│   └── scripts/        # nm-connect.py, bt-agent.py (section 4)
├── hypr/               # Hyprland Lua config (section 5)
├── configs/            # alacritty, hypridle, hyprpaper, SDDM theme, PAM for the lock screen
├── assets/             # wallpapers, bundled font and its license
├── packaging/          # RPM .spec files
├── kickstart/          # install description, ISO build, first-login step
├── docs/               # section 9
├── Makefile            # dev, lint, rpm, iso
└── LICENSE             # MIT
```

Shell name: `qs -c hyprdora`. User settings: `~/.config/hyprdora/settings.json`.

## 3. System composition

**`hyprdora` package (desktop):**

- Hyprland: `hyprland`, `hyprpaper`, `hypridle`, `polkit` (the shell is its agent), XDG portals, `xdg-utils`, Qt Wayland
- Shell and its dependencies: `quickshell`, `brightnessctl`, `playerctl`, `adwaita-sans-fonts`, `python3-gobject`, `libnotify`, JetBrainsMono Nerd Font (pinned version, OFL text included)
- System: PipeWire, WirePlumber, BlueZ, NetworkManager with Wi-Fi, `wpa_supplicant`, `iw`, `nmtui`, `power-profiles-daemon`, `gnome-keyring`, `gvfs`, `xdg-user-dirs`, CUPS, `system-config-printer`
- Desktop tools: `cliphist`, `wl-clipboard`, `grim`, `swappy`, `wf-recorder`
- Applications: `alacritty`, `btop`, Nautilus with a small extension (Set as Wallpaper, Open in Terminal), `gvfs-mtp`, `gvfs-smb`, Loupe, Showtime, Papers, `gnome-calculator`, `gnome-text-editor`, `gnome-disk-utility`
- Base tools: `git`, `curl`, `wget`, `tar`, `unzip`, `p7zip`, `pciutils`
- Look and login: Papirus, Bibata Modern Ice (24), dark GTK theme, wallpaper, SDDM with the Hyprdora theme
- Snapshots: `snapper`, a `dnf5` action that takes a snapshot around each transaction, `btrfs-assistant`

**Personal layer (separate from the desktop):** `neovim`, VS Code, Zen + Flatseal (flatpak), Discord, FileZilla, GIMP, Fedora Media Writer, OnlyOffice (official repository), virt-manager, `docker-ce`, Python 3, Node.js, Java 25, .NET 10, zsh + Oh My Zsh (agnoster). Zen is set as the default browser in this layer.

**Hardware-dependent (detected):** `wl` (Broadcom), the FaceTime HD camera driver (`akmod-facetimehd` from the `mulderje/facetimehd-kmod` COPR), full codecs and VA-API from RPM Fusion (`intel-media-driver` or `mesa-va-drivers-freeworld`), NVIDIA.

- Hybrid laptop: desktop on the Intel GPU, NVIDIA on demand (`prime-run`). NVIDIA as the only GPU: environment variables included in the config.
- Secure Boot: a signing key is prepared only when Secure Boot is on and a module is built (NVIDIA, `wl`). In practice this means the Legion.

**Repositories:** RPM Fusion, `sdegler/hyprland`, `peterwu/rendezvous`, Microsoft (VS Code), Docker, OnlyOffice, Flathub.

**Dropped:** `gum` menu, gaming stack, OpenCL/CUDA/ROCm, `vulkan-tools`, waybar, swaync, `wiremix`, `nwg-displays`, `nwg-look`, `bluetui` and the Rust build, VirtualBox, `lazydocker`, `hyprpicker`, KeePassXC, `sys-power.sh`, `power-profiles.sh`, `toggle_audio.sh`, `screenshot.sh` (replaced by section 6), `slurp` (same), `set-wallpaper.sh` and `save-monitors.py` (moved to QML, section 4), the `nwg-displays` window rule.

**Where things go:**

| Place | Contents |
|---|---|
| kickstart | repositories, drivers, system services, snapper, `/var/lib/docker` subvolume, keyring PAM |
| package | applications, shell, default configs, default applications, themes |
| first login | keyboard layout, Oh My Zsh, `xdg-user-dirs-update` |

## 4. Shell

Carried over from GUI-demo: bar, action center, Wi-Fi, Bluetooth, audio, notifications, media, OSD, power page, displays, system stats, weather, calendar, brightness floor with IPC, low-battery warnings.

Changes during the move:

- Rename from `gui-demo` to `hyprdora`.
- Personal values move out of the code. `settings.json` overrides defaults: language, weather location, terminal command, `brightnessMinimum`, `calendarScrollDelay`. The weather module stays hidden until a location is set.
- `dev-on.sh`, `dev-off.sh`, `dev-binds.sh`, `install.sh` and `uninstall.sh` are removed, replaced by `make dev`.
- All comments and identifiers in English, all UI strings through i18n.

### Logic lives in QML

Anything that needs logic and can run in QML is written in QML. External programs such as `grim` or `hyprctl` are still called, directly through `Process`, with no wrapper scripts.

| Today | After the move |
|---|---|
| `screenshot.sh` | capture service in QML (section 6) |
| `set-wallpaper.sh` | `Wallpaper` service: `hyprctl hyprpaper` plus writing `hyprpaper.conf`. The Nautilus extension calls `qs -c hyprdora ipc call wallpaper set %f` |
| `save-monitors.py` | stage 2, with the move to Lua: `FileView` writes all of `monitors.lua` atomically and keeps the previous version as `.bak`. The block merging is no longer needed, because the file is fully generated |
| `dev-*.sh`, `install.sh`, `uninstall.sh` | removed, replaced by `make dev` and the RPM |

Verified on 2026-11-08 under `qs`: atomic `FileView` writes and XDG paths from `StandardPaths`, which replace `xdg-user-dir`.

**Two Python helpers stay, because QML cannot do their job:**

- `bt-agent.py` exports a pairing agent object on D-Bus, and QML cannot export D-Bus objects.
- `hyprdora-portal` is the wallpaper portal backend, so "Set as Background" in Nautilus, Loupe and other apps changes the HyprDora wallpaper. It exports a D-Bus object too.
- The Nautilus extension adds "Open in Terminal"; Nautilus loads extensions only in Python or C.
- `nm-connect.py` sends the Wi-Fi password over D-Bus. `Quickshell.Networking` does not accept a password, and passing it to `nmcli` as an argument would expose it in the process list.

**Shell stays only where the shell is not running:** kickstart `%post` and the first-login step.

### Internationalization

Qt's standard `qsTr()` needs a `QTranslator` installed from C++. The `qs` binary does not use one, and QML cannot install it, so `qsTr()` would always return the source text. HyprDora uses a small `I18n` singleton instead.

- `shell/i18n/<lang>.json`, flat keys. **Adding a language means adding one file.**
- `I18n.t("wifi.connecting", { ssid })`.
- Plurals as `one`/`few`/`many`/`other` objects, because Polish needs three forms. Languages with simple plurals need only `one` and `other`; a rule table in `I18n` selects the form.
- A missing key falls back to `en`. Dates and month names come from `Qt.locale()`, replacing the hardcoded Polish names.
- Setting `language`: `auto` by default, which uses the system language when a translation exists and `en` otherwise. `en` and `pl` ship from the start.

## 5. Hyprland in Lua

Verified on 2026-11-08 on a nested Hyprland 0.56.2: Lua config loads, and `require` works across files and directories.

```text
/usr/share/hyprdora/hypr/        # from the package, updated by dnf
├── init.lua                     # only loads the others
├── apps.lua                     # terminal, file manager, launcher
├── binds.lua                    # ALL default keybindings
├── autostart.lua  env.lua  look.lua  input.lua  rules.lua
├── gpu/                         # hybrid.lua, nvidia.lua (stage 6)
└── lib/                         # keybinding merging, named actions, user file loading

~/.config/hypr/                  # user files
├── binds.lua                    # keybinding changes
├── settings.lua                 # other overrides
└── monitors.lua                 # generated by the shell
```

`hypridle` and `hyprpaper` are separate programs and keep their `.conf` files.

**Keybindings in one place.** `binds.lua` is a plain list with no logic, one binding per line, grouped by topic:

```lua
return {
  -- Applications
  { "SUPER + T",      act.terminal,      "Terminal" },
  { "SUPER + E",      act.files,         "Files" },
  { "SUPER + SPACE",  act.launcher,      "App launcher" },

  -- Panels
  { "SUPER + A",      act.action_center, "Action center" },
  { "SUPER + Escape", act.power_menu,    "Power" },
  { "Print",          act.capture,       "Screenshot and recording" },
}
```

The user file lists only what differs:

```lua
return {
  { "SUPER + T", act.exec("kitty"), "Terminal" },  -- replaces the default
  { "SUPER + P", false },                          -- disables it
}
```

`lib/binds.lua` merges both lists, reports duplicate keys, then calls `hl.bind`. Descriptions allow a keybinding cheat sheet in the action center later and a generated table in the README. Brightness keys use the shell IPC with `brightnessctl` as a fallback when the shell is not running. The MacBook has no `Print` key, so capture also gets a `SUPER` shortcut.

**What Lua mode breaks.** Old `hyprctl` syntax returns errors (verified). The shell must be ported in the same stage:

| Location | Today | Without the change | After the change |
|---|---|---|---|
| `modules/bar/Workspaces.qml:64-65` | `Hyprland.dispatch("workspace N")` | clicking workspaces stops working | `hl.dsp.focus({ workspace = N })` |
| `services/Session.qml:18` | `hyprctl dispatch exit` | logout stops working | `hyprctl dispatch 'hl.dsp.exit()'` |
| `services/Displays.qml` | `hyprctl keyword monitor`, `--batch` | **monitor changes and automatic rollback stop working** | `hyprctl eval 'hl.monitor({...})'` |
| `scripts/save-monitors.py` | block in `monitors.conf` | saving the layout stops working | `monitors.lua` written from QML |

Verified on a nested instance with a virtual monitor: `hyprctl eval` with `hl.monitor` applies rules, including the automatic revert and the watchdog. A real external monitor is checked by hand.

## 6. Capture tool

One tool for screenshots and screen recording, GNOME style. One icon-only button with a tooltip in the action center, directly below the Wi-Fi and Bluetooth tiles, like today's power button. `Print` and a `SUPER` shortcut open the same tool.

- Opens straight into **area selection**: a dimmed overlay on every screen, drawn in QML. `slurp` cannot show a toolbar, so it is not used.
- Toolbar at the bottom: Area / Full screen / Window, Screenshot / Record, and a capture button. Esc cancels.
- The overlay and the action center hide before capture, so they never appear in the result.
- `grim -g` and `wf-recorder -g` receive the coordinates. Window geometry comes from `hyprctl -j clients`.
- **Screenshot:** saved to `Screenshots` in the XDG Pictures directory and copied to the clipboard. A notification offers editing in `swappy`. All of it is a QML service. The only inline shell is a one-line `sh -c` that redirects the file into `wl-copy`, because `Process` cannot send binary data to stdin.
- **Recording:** saved to `Recordings` in the XDG Videos directory. System sound and the microphone can be switched on in the toolbar, both off by default; recording both mixes them in a temporary PipeWire sink, because `wf-recorder` takes one source. A red indicator with elapsed time on the bar stops it without opening a panel. Stopped with SIGINT so the file is finalized. A notification opens the result. Hardware encoding through VA-API when available, because software encoding is heavy on the i5-5350U.

## 7. Code conventions

- **English everywhere in the repository:** code, comments, Markdown, commit messages.
- **One-line comments only where truly needed.** They explain why, not what.
- **Doc comments on functions:** purpose, parameters, return value, JSDoc style in QML/JS, LuaLS `---@param` in Lua, docstrings in Python, a header comment in shell scripts. Required in services, libraries and scripts; trivial signal handlers are exempt.
- **Commits:** Conventional Commits (`feat(shell): ...`), one branch per stage, merged to `main`.
- **QML before scripts:** logic that can run in QML is written in QML (section 4).
- **Linters:** `qmllint`, `qmlformat`, `shellcheck`, `ruff`, `stylua`. CI on GitHub Actions runs the linters; RPM builds can be added later.
- Documentation changes land in the same commit as the code they describe.

## 8. Testing

No automated tests: Qt's test tools do not work with a `qs` shell without workarounds. Changes are checked by the linters, `Hyprland --verify-config` for the Lua config, and manual testing, with a checklist for hardware and interaction (Bluetooth, Wi-Fi, touchpad, monitors) in `docs/testing.md`.

## 9. Documentation

Markdown in `docs/`, rendered by GitHub. GitHub Pages can be added later from the same files.

```text
docs/
├── architecture.md      # how the parts fit together, what changes where
├── installation.md      # ISO, kickstart, packages
├── development.md       # make dev, adding a language, adding a keybinding
├── testing.md           # manual hardware checklist
├── hardware-quirks.md   # BlueZ, wl, Hyprland focus and other findings
├── roadmap.md           # this plan
├── known-issues.md
└── decisions/           # one short file per decision: context, decision, rejected options
```

The first decision records: RPM + kickstart over scripts and `bootc`, one repository, moving the shell instead of rewriting it, Hyprland in Lua, custom i18n over `qsTr`, Open-Meteo, `OnDemand` keyboard focus, perceptual brightness curve with a floor. The findings and results recorded in GUI-demo's `PLAN.md` are distilled into these files.

## 10. Development mode

`make dev` starts the shell from the repository in a nested Hyprland, without touching the running session. Until stage 2 it uses the minimal `hypr/dev.conf`, then the repository's Lua config. Config files are redirected to `build/dev/config`. Verified: a nested Hyprland runs alongside the live one and is controlled separately with `hyprctl -i`.

## 11. Stages

Stages 0 to 5 are done. Each stage ends with something that can be run and judged. Commits follow the "test, then approve" flow.

| Stage | Scope | Done when |
|---|---|---|
| 0 | New local repository, layout, license, `Makefile`, linters, docs skeleton, first decision records | repository exists locally |
| 1 | Move the shell in logical commits; rename; `settings.json`; English; i18n with `en` and `pl`; `Wallpaper` service; `make dev` | shell runs from the new location |
| 2 | Hyprland config in Lua, keybindings, shell port to the new commands | laptop runs on Lua; monitors, logout and workspaces verified |
| 3 | Displays: snap to the center of a neighbor's edge, as a third option next to the two corners, so an ultrawide lines up with the laptop. Then the capture tool (section 6) | a screen can be centered on an edge; screenshot and recording work from the panel and shortcuts |
| 4 | RPM packages (`hyprdora`, personal layer) built locally | package installs on clean Fedora in a VM |
| 5 | Kickstart and ISO (`mkksiso`), first-login step, tests in virt-manager | ISO produces a working desktop in a VM |
| 6 | Real hardware: MacBook, then the AMD desktop, then the Legion (NVIDIA, Secure Boot) | MacBook done; the AMD desktop and the Legion are postponed |
| 7 | The backlog below | as needed |

The MacBook is reinstalled only after the ISO passes VM tests and a backup is made.

`qs -c hyprdora` finds the packaged shell through `/etc/xdg/quickshell/hyprdora`. The login session starts Hyprland with `--config /usr/share/hyprdora/hypr/init.lua`, so the desktop works before any user file exists.

### Backlog

Agreed on 2026-11-11, in this order. Items marked *plan first* start with a short design to approve.

Safety and stability:

- [x] Automatic shell restart, since the idle lock lives in the shell
- [x] Power button: a short press does nothing, holding it for 2 seconds powers off
- [x] Test a rollback to a snapper snapshot: `hyprdora rollback`, package protection and a space limit for snapshots (see recovery.md)
- [x] System restore in the settings, for when the desktop still works: after the administrator password, a window lists the snapshots taken before changes, with a confirmation before restoring; a "create snapshot" entry below it
- [x] Snapshot entries in the boot menu (research): dropped for now, since there is no ready solution. grub-btrfs is not in Fedora's repositories and does not check that a snapshot has modules for the kernel in the separate `/boot`. Tested in a VM: Fedora boots a read-only snapshot through a hand-made BLS entry (only auditd fails), so own entries in `/boot/loader/entries`, refreshed after dnf and cleanup, plus `hyprdora rollback` accepting a system run from a snapshot, would work if wanted later
- [x] `hyprdora update`: dropped. Once packages come from a dnf repository, every `dnf upgrade` updates them, so no separate command is needed

Quick fixes:

- [x] `SUPER + B` opens the browser
- [x] Function keys: media keys verified (F7 to F9 send the expected codes), keyboard backlight (F5, F6) and F4 (Launchpad) opens the launcher
- [x] Center the capture and settings icons in the action center: moved to known issues, low priority
- [x] Spinner while scanning for Wi-Fi networks and Bluetooth devices
- [x] Fedora Media Writer installed by default, in hyprdora-extras

Medium:

- [x] Resize and move a capture selection by its edges instead of drawing it again
- [x] Reorganize the action center: notifications and the media player open next to the clock, devices and application volumes unfold under each volume row, display settings moved to the settings menu
- [x] Ethernet icon, shown only while a cable is connected (built without hardware to test)
- [x] VPN: a tile and a page in the action center to import WireGuard and OpenVPN files, connect, disconnect and delete, with an icon shown only while a VPN is active
- [x] Bluetooth headset options (research): dropped. WirePlumber switches between the playback (A2DP) and headset (HFP) profiles by itself and picks the best codec; noise cancelling of the headsets is controlled only by their makers' software. Software noise suppression for the microphone (RNNoise, in Fedora) remains possible if wanted later
- [x] Icons while an application uses the microphone or the camera
- [x] Icon while an application records or shares the screen
- [x] Idle pause ("coffee"): a toggle that stops dimming, locking and suspending for a while
- [x] Notice on the bar when system updates are available, installed in a terminal on click
- [x] Keyboard shortcut cheat sheet in the settings, read from Hyprland so the user's own bindings show too

Second round, agreed on 2026-11-12, done before the large items:

- [x] A click outside the settings menu closes the whole action center
- [x] Scrolling the action center is not caught by a slider under the pointer
- [x] `make install` makes the shell flash once, not on every replaced file
- [x] Battery icon white by default, colored only when low, with a charging bolt on power
- [x] Missing folder shortcuts in the Nautilus sidebar: the first login bookmarks the user folders, as xdg-user-dirs-gtk does on GNOME
- [x] Battery panel on a click on the battery icon: power profiles and time to empty or to full
- [x] While updates wait, the power menu offers update and power off, update and restart: Flatpaks first, then `dnf upgrade --offline` downloads the packages and `dnf offline reboot` (with `--poweroff` for the first) installs them at boot (tested in a VM: 11 updates installed at boot with snapper snapshots before and after; power off without packages just powers off)
- [x] Touchpad gestures in the shortcut list, written by hand because Hyprland does not list them
- [x] Automations in the settings: do not disturb, coffee and muted sound on a schedule of hours and weekdays (on when the hours start, off when they end); sound back on when headphones connect; a VPN that connects on any network except listed home Wi-Fi networks, which disconnect it
- [x] Login and lock screens: SDDM keeps its terminal look, now in the shell's colors, with recovery help under `/help`; its Caps Lock state is not available under Wayland (SDDM's Wayland keyboard backend is a stub), so only the lock screen shows Caps Lock. hyprlock is replaced by a lock screen in the shell that looks the same; only a successful PAM check unlocks it, and a shell that stops while locked ends the session

Third round, proposed on 2026-11-14, in this order:

- [x] A click on a notification without a default action opens the application that sent it, as GNOME does. Found with the Nextcloud desktop client: it sends one summary such as "3 notifications" with no text and no actions, keeping the details in its own window, and a click did nothing
- [x] No flash of the desktop at sign-in: Hyprland showed its own wallpaper, logo and splash text before hyprpaper drew HyprDora's wallpaper; it now shows plain black, the color of the login screen. The shell also moved a lone laptop screen from its saved position in the docked layout to 0x0 at sign-in, which reconfigured the screen so it flashed and slid in from a corner; it now does that only after a monitor is unplugged
- [x] Updates: the list of packages to install, and showing the notice less often, like GNOME Software (ordinary updates about once a week, security updates at once) rather than every day, as Fedora publishes them
- [x] Network printers and scanners: a settings category lists the added printers (default, remove) and the driverless network printers found (add), and the scanners `sane-airscan` finds, which need no adding; Simple Scan and system-config-printer for the rest, the latter only under "more settings" and hidden from the launcher
- [x] Prefer a saved fixed Wi-Fi network over a phone hotspot at start and on wake: a hotspot (an Android one is metered, an iPhone one has the gateway 172.20.10.1) gets a lower autoconnect priority in NetworkManager, so a fixed network in range wins, while a hotspot chosen by hand stays
- [x] Icon theme chosen under Appearance, Papirus or Adwaita, for the shell and GTK applications together: Quickshell reads it at start from `QS_ICON_THEME`, which `shell-start` sets from the settings, so a new choice restarts the shell. Tela is not in Fedora, so it is left out
- [x] Background applications such as Nextcloud in the bar: already shown by the tray
- [x] About in the settings: the computer's name, changed in place (the pretty name and a network name made from it, through systemd-hostnamed after the administrator password), and the model, processor, memory, graphics, disk, system and its type, windowing, support end and versions, with a button that copies them as text

Fourth round, proposed on 2026-11-16, in this order:

- [x] No brightness indicator when the screen dims or brightens for idleness: the shell sets those levels quietly
- [x] Printer settings hidden from the launcher; they open from "more settings" under printers and scanners
- [x] Metered ("taryfowe") connections, as GNOME, Windows and macOS do: on them nothing downloads in the background (the repository refresh and the Flatpak check wait, installing by hand still works); every saved Wi-Fi network has a switch, since a router with a SIM card does not report it; an Android hotspot reports itself and an iPhone hotspot is marked automatically. The updates panel always shows how much the updates download
- [x] A full-screen "downloading updates" screen before an update and restart or power off, held as a session lock so shortcuts and applications are out of reach: updates and megabytes downloaded, and only "power off now" while it downloads; after a failure, which changed nothing, also try again or back to the desktop. The download runs as a system service that holds off sleep and the lid switch
- [x] HyprDora's own boot theme (Plymouth): black, the login screen's ">:" prompt in the same place typing a short English log, each finished line moving up with "[ ok ]", paced by Plymouth's boot estimate; a text progress bar while updates install. The splash starts on the real graphics driver and stays until the login screen draws, the console clears the firmware's picture (fbcon=nodefer), and the GRUB menu is hidden unless Esc is pressed
- [x] An installer that does not look stuck: the installer checks no package signatures, so every package from outside Fedora comes from the ISO itself, each checked at build time against a pinned key (packaging/iso/build-repo.sh), and the installer counts them with the rest; drivers are picked by %pre from the PCI devices; Fedora comes through metalinks. The post-install setup only configures and installs the two Flatpaks, about three minutes. Not yet seen on real hardware: the Broadcom and FaceTime drivers from the ISO
- [x] A HyprDora logo: a lowercase h of rounded green blocks on a dark tile, and one round stroke up to 32 px; drawn by packaging/logo/make-logo.py, shown in the README, on the about page, as the icon named hyprdora, and as the bar's button for the action center
- [x] HyprDora's own name, as Fedora asks of remixes ([decision 9](decisions/0009-own-release-identity.md)): hyprdora-release (os-release "HyprDora 44", ID=hyprdora, ID_LIKE=fedora; Fedora's presets, dnf defaults and RPM macros kept) and hyprdora-logos replace fedora-release and fedora-logos on the ISO; the installer, still Fedora's, gets HyprDora's name, logo and colours from a product.img, and its boot menu names HyprDora
- [x] F3 (Mission Control on a Mac keyboard) and three fingers up open an overview in the shell, no Hyprland plugin: the current workspace's windows with live previews (ScreencopyView of each toplevel), a click, or arrows and Enter, switch to one; a strip of workspaces at the top, a click switches, and a window dragged onto one moves there without following it. The launcher moved to a pinch with the thumb and three fingers, as Launchpad on a Mac
- [-] Google and Microsoft calendars, investigated on 2026-11-17 and dropped for now: no simple, clean way exists. Reading and changing events needs an OAuth application registered with Google and Microsoft. Borrowing GNOME's through GNOME Online Accounts works only with GOA's own window, which has no command line, and its sign-in library (libgoa-backend) is declared unstable API that shows its own GTK dialog. Registering HyprDora's own application means Google's verification (a verified domain, privacy policy and video) and, for Microsoft work accounts, a verified publisher, which needs a company. Read-only private iCal addresses would avoid all that but were not wanted. Maybe one day, not soon. The calendar helper was split into modules (core, caldav, nextcloud, local, cli) on the way
- [x] An offline calendar, kept on this computer only: one iCalendar file per event in ~/.local/share/hyprdora/calendars/local (a directory only its owner may open), shown with the Nextcloud calendars and on its own without any account; repeating events are expanded by the helper with dateutil; no attendees, as nothing would send invitations. The form offers the calendar used last
- [x] A place to find applications: GNOME Software, which lists RPM repositories and Flathub by category and name, chosen over Bazaar (Flathub only) and KDE Discover (Qt, about 530 MB); its updates are off (allow-updates=false), so they stay with the shell's panel. It would stay in the background as a 400 MB service, so the shell quits it a few seconds after its last window closes (`quitWithLastWindow` in the settings). Installing and removing software asks for the administrator password again, kept for 5 minutes, and importing a repository key asks every time, overriding Fedora's rules that let wheel do both silently
- [x] Notification history across restarts: saved to ~/.local/state/hyprdora/notifications.json in a directory only its owner may open, for 7 days and at most 100; a saved entry keeps its application's icon and a click opens the application, while actions and pictures stay with the sending program. Transient notices and those of screenshots and recordings are not kept

Large:

- [x] New application launcher in the shell instead of rofi: a list near the top of the screen with search that forgives diacritics and typos, most used first, a calculator, `>` to run a command and a web search; clipboard history in the same window. Opened by SUPER + SPACE, F4 and a three-finger swipe up
- [x] Light and dark theme in the settings, under Appearance: the shell, GTK and libadwaita applications, and through the settings portal Flatpaks and browsers; the terminal, login and lock screens stay dark
- [x] Online accounts in the settings, added only through the provider's own sign-in in the browser (Nextcloud Login Flow v2 for now); the app password is kept in the keyring and revoked on sign-out
- [x] Calendar events from Nextcloud over CalDAV, with a cache for use away from home: dots on days with events, today's events shown at once and another day's on a click; adding events with a description, repetition (with an optional last day) and attendees invited by Nextcloud; deleting an event, or one occurrence or the whole series of a repeating one; details on a click; reminders as notifications. Editing existing events is left to Nextcloud. GNOME Calendar with evolution-data-server was tried first and dropped: it adds CalDAV only through GNOME Online Accounts in GNOME Settings
- [x] Disk encryption with one password at start (decided): not automated. LUKS for the whole disk is chosen in the installer as before; TPM unlocking is set up by hand where wanted (`systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7`, `tpm2-device=auto` in `/etc/crypttab`, `dracut -f`). An automatic first-boot setup was built and tested in a VM, then dropped as not worth it
- [x] Backup of personal files in `/home` (decided): HyprDora does nothing. Files are kept by syncing with Nextcloud, whose official desktop client is installed by hand where needed; a one-file archive was considered and dropped
- [x] Password prompt for administrator actions in the style of the shell, replacing hyprpolkitagent: the shell is the session's polkit agent and shows polkit's message and action id; polkit's own helper checks the password
- [x] Default applications in the settings: browser, mail, files, terminal, text editor, images, video, music and PDF, written to `mimeapps.list` and `xdg-terminals.list`, which SUPER+E and SUPER+T follow

Fifth round (2026-11-19):

- [x] Touchpad scrolling direction in the settings, shown only when a touchpad is present
- [x] Wi-Fi and Bluetooth tiles: the arrow to their page has a grey hover that looks off on a switched-on tile, and flashes dark green before turning grey
- [-] Renaming a file or folder in Nautilus: after a few presses of an arrow key, or holding it, the cursor jumps one character back and forth. Not HyprDora's: Nautilus's own rename popover only (Nautilus 50.4, GTK 4.22.5); its location bar, Text Editor, GNOME Software's search and the save dialog's name field behave. HyprDora's Nautilus extension only adds a menu item. Left to Nautilus; no matching report found on 2026-11-19
- [x] Removable drives on the bar (USB sticks, SD cards, USB disks): an icon while one is plugged in, a list on hover, and safe removal of each, which also powers it off as on Windows, with a clear sign when a drive cannot be removed yet
- [x] Update and restart: the download count showed 5/5 and 1 kB, then about 5/25 and a few MB, while the update panel said 600 MB
- [x] The sound icon on the bar opens a sound panel of its own, as Wi-Fi, Bluetooth and the battery have theirs; the sound controls are one component, used both there and in the action center, so the two look the same
- [x] On-screen indicators (volume, screen and keyboard brightness) only for a change the user makes: keys, a headset's buttons or another device's controls, and not for an automatic one, such as the volume of the next output after Bluetooth headphones disconnect. The indicator is started by the user's action rather than by every change of the value
- [x] With an external screen connected, an icon on the bar opens the display settings, the same as on the settings page, for quick changes (tested in a nested Hyprland; not yet with a real external screen)
- [x] Calendar in two columns: the month and the weather on the left, the selected day's events on the right, always shown, with "No events today", "tomorrow" or "on this day" when there are none; the panel is as tall as the left column, and a long list or the new event form scrolls
- [x] Weather and date on the bar as one element: hovering either lights up only itself, which suggests two separate things, while both open the same panel

Review of the whole project (2026-11-19), in stages, each ending in a report the author decides on before anything changes; what one stage finds may change the next:

- [x] 0. A map: every module, component, service and script, and what uses what
- [x] 1. What belongs where: settings that deserve the action center or the bar, things buried too deep, things missing. Decided:
  - [x] A1. The action center's displays page goes; nothing opens it any more, and the displays live in the settings and the bar's panel
  - [x] A2. The bar's power profile icon opens the battery panel, which holds the profiles, not the whole action center
  - [x] A3. Restoring the system and taking a snapshot leave the list of setting categories as one category, "System restore", whose page holds both
  - [x] A4. The settings menu in groups: devices; look and behaviour; region; account and system
  - [ ] After the review: a keyboard shortcut cheat sheet on a key (B1); keyboard layouts in the settings, with a bar indicator for more than one (C1); "Mouse and touchpad" with pointer speed and tap to click (C2); choosing the wallpaper in the settings (C3)
  - Not done: a do-not-disturb tile and a dark theme tile in the action center, night light. Kept as they are: Wi-Fi, Bluetooth and VPN open the action center's pages from the bar; the system card stays in the action center
- [x] 2. Shared components: one component wherever two places show the same thing (Wi-Fi, Bluetooth, sound, buttons that differ only in their icon), with what differs passed in; values written in place of Theme's tokens
  - [x] S1. One frame for the panels at the bar (BarPanel): the window, closing by a click outside and Esc, the delay before the window goes, the slide in, the background
  - [x] S2. One way to open panels in Panels.qml instead of a copy of open, close, toggle and IPC per panel; the IPC names change, and every script and binding that called the old ones changes with them
  - [x] S3. Font sizes and corner radii as named tokens in Theme instead of numbers written in place
  - [x] S4. One list row (ItemRow): icon, title, subtitle, buttons on the right, hover and the active row's highlight
  - [x] S5. One delete button that asks for a second click; deleting a VPN connection or a printer, one click so far, asks for it too
  - [x] S6. One row with a slider for brightness and volume
  - [x] S7. ConfirmButton among the shared components
  - [x] S8. Wi-Fi's, Bluetooth's and VPN's icon and summary worked out in their services, with a shared base where their logic overlaps
  - [x] S9. Shared empty and loading states
  - [x] S10. One page header with a back arrow: only the action center has one, so instead Title, the bold title nine panels, windows and pages drew on their own
  - [x] S11. One scrolling area with the thin scroll bar, used by the action center, notifications, updates and the calendar
- [x] 3. Code quality: better ways to solve a problem, clean code, dead code, translation keys unused or missing in one language, background processes, timers and polling, keyboard use (Esc, arrows) the same in every panel
  - [x] EventSources in shell/base: every watch of the local system goes through it, one process, file watch or poll per source however many listen, started on the first listener and stopped after the last, ending with the shell and restarted if it fails (nmcli monitor, udisksctl monitor, pactl subscribe, the settings file, monitors.lua, backlight, update progress, Caps Lock, VPN counters)
  - [x] B3. The camera watched with inotify (inotify-tools) instead of a process every 4 seconds
  - [x] settings.json and monitors.lua made by the shell when missing, at start or after being deleted, with a note on top: watching needs a file, and a deleted folder ends the watch
  - [x] Memory: measured, nothing changes. The shell's ~128 MB RSS is ~105 MB of its own (56 in RAM, 30 swapped out, 20 of graphics buffers); a bare Quickshell takes 26, the JavaScript heap ~4, the rest is QML objects; no leaks. The one large saving, software rendering (about 55 MB), crashes the window overview and gives up the media cover's rounded corners and any GPU effect, so it is not worth it
  - Kept: B5, the Bluetooth discovery retry every 3 seconds; it runs only while the Bluetooth page is open and discovery is off, and a discovery BlueZ refuses right after power-on changes no state an event could follow
  - [x] B6. ScheduledTask: one policy for when downloads run (not offline, waiting on a metered network unless allowed, catching up after the network returns or after waking); weather downloads on a metered network, updates wait, the calendar reads its local calendars offline too and reads again when the network returns; the data stays in its services
  - [x] A1. The media panel's position moves while the panel is open, not the action center; A2. notification times refresh with the notification panel
  - [x] C1, C2. Unused icons and translation keys removed
  - [x] D1. The calendar's event form in a file of its own; D2. the display layout's geometry out of Displays.qml into DisplayGeometry.js, moved without changes
  - Kept: Capture.qml and Network.qml whole; arrows in the action center's lists
- [ ] 4. Security, on the code as it stands after the stages above; anything serious found earlier is reported at once
  - [x] S1. The launcher passes what it runs to Hyprland as a Lua string the text cannot leave; a clipboard entry, which any web page may fill, could close the old long string and run a command of its own (shown in a nested Hyprland)
  - [x] S2. Online accounts: https only, in the shell and the calendar helper; the server typed is kept, the sign-in and poll addresses must lead back to it, a login has no control characters, and every value given to curl is escaped
  - [x] S3. ptrace limited to a program's own children (kernel.yama.ptrace_scope = 1), so a program running as the user cannot read the memory of the shell, the keyring or a browser
  - [x] S4. Installing a Flatpak runtime passes without a password because Flatpak's app-update implies it; adding a remote still asks, so it stays, and the rule no longer lists it
  - [x] S5. Ten wrong passwords lock the account for five minutes on new installs (faillock); the lock screen shows PAM's reason
  - [x] S7. Clipboard history in memory only ($XDG_RUNTIME_DIR), so a password copied by hand never reaches the disk; it ends with the session
  - Kept: disk encryption stays the installer's choice; Hyprland's permission system and fake password windows, which the shell cannot prevent
- [x] 5. Documentation: docs/ and the README describe what the code does after the review
  - [x] The README's layout and links, the architecture (folders, EventSources and ScheduledTask, panels, root helpers), make install, the testing checklist, known issues, every installed file, and hardware quirks found in stages 3 and 4
  - [x] docs/security.md, and decisions 10 (EventSources and ScheduledTask) and 11 (stricter security settings)
  - [x] The nested test runner in the repository: tools/nested-test.sh
  - [x] Comments that still placed the notification history in the action center
  - [x] Toasts end when the notification panel opens, which lists them, and a notification arriving while it is open shows only there
- The whole project is in scope: the shell, the Hyprland config, scripts, packaging and the kickstart

Terminal and editor (2026-11-22), as VS Code takes too much of 8 GB:

- [x] Zed from Flathub on new installs, beside VS Code
- [x] Alacritty opens in tmux: one shared session, each window its own view of it and a new tab in its folder; tmux's own key bindings, with the mouse on and tabs counted from 1
- [x] LazyVim as Neovim's default config from hyprdora-extras, with the languages used here, QML through qmlls, and Diffview; its tools (ripgrep, fd, lazygit, tree-sitter, gcc) as dependencies

Before the repository goes public:

- [ ] Updates for installed systems: HyprDora's packages come only from the ISO or a local build, so an installed system gets no fixes and cannot move to the next Fedora release, which needs hyprdora-release for it. A COPR project built from the GitHub repository, enabled by hyprdora-repos
- [ ] README: the status still says virtual machines only; screenshots and a short tour of the shell
- [ ] CI: linters on GitHub Actions, as planned in section 7
- [ ] Review for personal content; decide whether hyprdora-extras (the author's own applications) stays on the ISO, becomes optional or moves out
- [ ] With a published ISO, where to get the sources of the GPL packages it carries from RPM Fusion and COPR
- [ ] A full `make iso` with sudo after the release identity change, and an install from the ISO on real hardware (the Broadcom and FaceTime drivers from the ISO not yet seen)

Later: battery charge limit to about 80% (this MacBook does not allow it; the Legion has a conservation mode, so it returns with the Legion). For F3, the Hyprspace overview plugin worked in a nested Hyprland 0.57.1, but a plugin must be rebuilt for every Hyprland release, which would tie Hyprland updates to it, so the overview was built in the shell.

## 12. Resolved decisions

| Topic | Decision |
|---|---|
| GitHub name | old repository renamed to `HyprDora-legacy` |
| Capture | single tool, area selection by default, options in a toolbar |
| Interface language | English by default in code; `auto` setting; `pl.json` ships |
| License | MIT; wallpaper and SDDM theme are the author's own work; Nerd Font under OFL with its license included |
| Automated tests | none; linters and a manual checklist |
| Scripts | logic in QML; Python only where QML cannot reach (D-Bus objects, the Nautilus extension); shell only outside the running desktop |
