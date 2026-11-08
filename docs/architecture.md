# Architecture

HyprDora has three parts:

- **`hyprdora` RPM:** applications, the shell and default configs in `/usr/share/hyprdora`. Updated by `dnf`.
- **Kickstart and ISO:** repositories, drivers, system services and snapshots. Disk layout and the user account are chosen in the installer.
- **First-login step:** user Hyprland config, shell environment, default applications.

User files in `~/.config/hypr` and `~/.config/hyprdora/settings.json` only override the packaged defaults, so package updates never overwrite them.

## Shell

`shell/services/` holds singletons that read state and perform actions, `shell/modules/` displays it, `shell/components/` holds reusable controls, and `shell/config/` holds the theme, settings and translations. Keeping these apart means a change in how a service gets its data does not touch the interface.

Keybindings reach the shell through IPC: `qs -c hyprdora ipc call <target> <function>`.

To save power, closed panels are not kept in memory, statistics are read only while visible, and nothing polls or animates continuously.

This document is expanded as each stage lands.
