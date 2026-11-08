# Architecture

HyprDora has three parts:

- **`hyprdora` RPM:** applications, the shell and default configs in `/usr/share/hyprdora`. Updated by `dnf`.
- **Kickstart and ISO:** repositories, drivers, system services and snapshots. Disk layout and the user account are chosen in the installer.
- **First-login step:** user Hyprland config, shell environment, default applications.

User files in `~/.config/hypr` and `~/.config/hyprdora/settings.json` only override the packaged defaults, so package updates never overwrite them.

This document is expanded as each stage lands.
