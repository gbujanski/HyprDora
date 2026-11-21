# 11. Security settings stricter than Fedora's

**Context.** The security review (see [security](../security.md)) asked what a program running as the user, or text from outside, can do with the desktop. Fedora's defaults favour convenience in a few places where the cost of a stricter setting is small.

**Decision.**

- Installing and removing software asks for the administrator password, kept for five minutes.
- `kernel.yama.ptrace_scope = 1`: a program may read the memory only of programs it started.
- Ten wrong passwords in a row lock the account for five minutes, set by the installer.
- The clipboard history is kept in memory only.
- Online accounts use https only.

**Consequences.** Attaching a debugger to a running program needs root. A user who mistypes the password ten times waits five minutes. The clipboard history does not survive a logout.

**Rejected.**

- Hyprland's permission system: it trusts programs by their path, so it would ask questions without stopping a malicious program, which can run an allowed one.
- Encrypting the disk by default: it stays the user's choice in the installer, made for each computer.
