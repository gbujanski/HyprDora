# Architecture

HyprDora has three parts:

- **`hyprdora` RPM:** the shell, the Hyprland config and the default configs in `/usr/share/hyprdora`, system files such as the polkit rules and the lock screen's PAM file, and every program the desktop needs as a dependency. Updated by `dnf`. [Installation](installation.md) lists where each file goes.
- **Kickstart and ISO:** repositories, drivers, system services, snapshots and the password limit. Disk layout and the user account are chosen in the installer.
- **First-login step:** user folders and their bookmarks. The shell takes the keyboard layout chosen in the installer by itself, and its welcome screen offers the applications beyond the base system.

User files in `~/.config/hypr` and `~/.config/hyprdora/settings.json` only override the packaged defaults, so package updates never overwrite them.

## Shell

| Folder | Contents |
|---|---|
| `shell/services/` | singletons that read the system's state and act on it: network, sound, drives, updates and so on |
| `shell/modules/` | what is shown: the bar, panels, the action center, the lock screen, the launcher |
| `shell/components/` | controls shared by modules: rows, sliders, buttons, the panel frame |
| `shell/config/` | theme, settings, icons and translations |
| `shell/base/` | `EventSources`, the one place the shell watches the system from |
| `shell/scripts/` | Python helpers where QML cannot do the job: Wi-Fi with a password, Bluetooth pairing, the host name |
| `shell/i18n/` | translations, one JSON file per language |

Keeping services apart from modules means a change in how a service gets its data does not touch the interface.

**Watching and downloading.** Services never start a watch of their own. A process that prints events (`nmcli monitor`, `udisksctl monitor`, `pactl subscribe`), a watched file or a poll goes through `EventSources`, which runs each source once however many listen, only while someone listens, and ends it with the shell. Downloads on a schedule (weather, updates, calendars) go through `ScheduledTask`, which waits for a network and catches up after waking. [Decision 10](decisions/0010-event-sources-and-scheduled-tasks.md) explains why.

**Panels.** `Panels` knows which panel is open and on which screen; at most one is. Each bar panel is a `BarPanel`, which loads its contents only while open, so closed panels take no memory, and closes on Esc and on a click outside.

**IPC.** Keybindings reach the shell through IPC: `qs -c hyprdora ipc call <target> <function>`. Panels open by name through one target, `panel`: `panel toggle sound`, `panel page power` for an action center page, `panel settings displays` for a settings category, `panel launcher clipboard`. No IPC function runs anything as root or returns a secret ([security](security.md)).

**Root actions.** Updates installed at restart, system restore and the applications chosen on the welcome screen run as small helpers in `/usr/libexec/hyprdora` through pkexec, so polkit asks for the password; the shell only starts them and shows their progress. The updates themselves download ahead of that as a system service, `hyprdora-update-download`, after each refresh of the package cache; the shell only reads how much is left.
