# Roadmap

Status: **accepted** · Created: 2026-11-08

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
├── configs/            # rofi, alacritty, hypridle, hyprlock, hyprpaper, SDDM theme
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

- Hyprland: `hyprland`, `hyprpaper`, `hyprlock`, `hypridle`, `hyprpolkitagent`, XDG portals, `xdg-utils`, Qt Wayland
- Shell and its dependencies: `quickshell`, `brightnessctl`, `playerctl`, `adwaita-sans-fonts`, `python3-gobject`, `libnotify`, JetBrainsMono Nerd Font (pinned version, OFL text included)
- System: PipeWire, WirePlumber, BlueZ, NetworkManager with Wi-Fi, `wpa_supplicant`, `iw`, `nmtui`, `power-profiles-daemon`, `gnome-keyring`, `gvfs`, `xdg-user-dirs`, CUPS, `system-config-printer`
- Desktop tools: `rofi`, `cliphist`, `wl-clipboard`, `grim`, `swappy`, `wf-recorder`
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
└── monitors.lua                 # generated by the shell, do not edit
```

`hypridle`, `hyprlock` and `hyprpaper` are separate programs and keep their `.conf` files.

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
- [ ] Restore the system from a snapshot in the settings, for when the desktop still works
- [ ] Snapshot entries in the boot menu, for when the system does not start (research): does the menu list only snapshots that still exist, and what happens to the entries and snapshots made after the one restored
- [ ] `hyprdora update`, once GitHub Actions builds packages into a dnf repository. Probably not needed: packages from a repository update with every `dnf upgrade` (research)

Quick fixes:

- [x] `SUPER + B` opens the browser
- [x] Function keys: media keys verified (F7 to F9 send the expected codes), keyboard backlight (F5, F6) and F4 (Launchpad) opens the launcher
- [x] Center the capture and settings icons in the action center: moved to known issues, low priority
- [x] Spinner while scanning for Wi-Fi networks and Bluetooth devices
- [x] Fedora Media Writer installed by default, in hyprdora-extras

Medium:

- [x] Resize and move a capture selection by its edges instead of drawing it again
- [x] Reorganize the action center: notifications and the media player open next to the clock, devices and application volumes unfold under each volume row, display settings moved to the settings menu
- [ ] Ethernet icon, shown only while a cable is connected (built without hardware to test)
- [ ] VPN connections set up in the settings, with an icon shown only while a VPN is active
- [ ] Bluetooth headset options: profile, codec, noise reduction where the headset allows it (research)
- [ ] Icons while an application uses the microphone or the camera
- [ ] Icon while an application records or shares the screen
- [ ] Idle pause ("coffee"): a toggle that stops dimming, locking and suspending for a while
- [ ] Notice on the bar when system updates are available
- [ ] Keyboard shortcut cheat sheet built from the descriptions in `binds.lua` (*plan first*)

Large:

- [ ] New application launcher (*plan first*)
- [ ] Light and dark theme in the settings, under Appearance
- [ ] Calendar events from Nextcloud first, then Google and Microsoft: preview on hover, adding events if possible. The Nextcloud server is reachable only from the home network or over VPN. Options first, then a decision whether it is worth it (research)
- [ ] Encrypted home directory unlocked by the login password, with no second password at boot (research)
- [ ] Default applications in the settings (*plan first*)

Later: computer name, an installer that does not look stuck, notification history across restarts, an action for F3 (Mission Control, `XF86LaunchA`). For F3, the Hyprspace overview plugin worked in a nested Hyprland 0.57.1, but a plugin must be rebuilt for every Hyprland release, which would tie Hyprland updates to it, so it was dropped.

## 12. Resolved decisions

| Topic | Decision |
|---|---|
| GitHub name | old repository renamed to `HyprDora-legacy` |
| Capture | single tool, area selection by default, options in a toolbar |
| Interface language | English by default in code; `auto` setting; `pl.json` ships |
| License | MIT; wallpaper and SDDM theme are the author's own work; Nerd Font under OFL with its license included |
| Automated tests | none; linters and a manual checklist |
| Scripts | logic in QML; Python only where QML cannot reach (D-Bus objects, the Nautilus extension); shell only outside the running desktop |
