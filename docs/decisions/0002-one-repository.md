# 2. One repository

**Context.** The shell and the system config depend on each other: keybindings call the shell's IPC, and the shell calls `hyprctl`. A change in one often needs a change in the other.

**Decision.** The shell, Hyprland config, packaging and installer live in one repository and are treated as one product.

**Rejected.** Separate repositories for the shell and the installer: cross-cutting changes would need coordinated commits and versions.
