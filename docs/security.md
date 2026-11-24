# Security

What HyprDora protects, how, and where its limits are. Reviewed on 2026-11-20.

## Who it guards against

- **Anyone outside the computer:** a web page, a file, a notification, a plugged-in device, a server the shell talks to. Nothing they send may run as code or reach a password. This is where the shell must hold, and it is what the review checked line by line.
- **A program already running as the user**, such as a script from the internet or a compromised package. On any Linux desktop, GNOME and KDE included, such a program can take the user's secrets: it can read every secret in the keyring, the saved Wi-Fi passwords and the browser's cookies, and wait in the autostart for a password to be typed. HyprDora cannot stop that, but it gives such a program nothing more: no password ever appears in a process's arguments, a file, a log or an IPC reply, and a few system settings below take away the easiest ways in. Programs from outside Fedora are best installed as Flatpaks, which keep them out of the user's files and of Hyprland's socket.
- **Someone with the laptop in hand:** only disk encryption helps, which the installer offers and leaves to the user.

## Passwords

| Where | How |
|---|---|
| Lock screen | checked by PAM with the console login's rules (`/etc/pam.d/hyprdora-lock`); the field is cleared after each try and nothing typed is shown |
| Administrator prompt | the shell is polkit's agent and only collects the password; polkit's own root helper checks it, so the shell cannot grant anything |
| Wi-Fi | sent on standard input to `shell/scripts/nm-connect.py`, which hands it to NetworkManager over D-Bus; a failed profile is deleted |
| BitLocker and other encrypted drives | sent on standard input to `udisksctl` (`--key-file /dev/stdin`) |
| Nextcloud | Login Flow v2: the account password is typed only in the browser; the app password Nextcloud issues goes to the keyring on standard input, and the calendar reads it from there for each request |
| Bluetooth pairing | the code goes on standard input to `shell/scripts/bt-agent.py` |

## Stricter than Fedora

- **Software installs ask for the password** (`10-hyprdora-software.rules`); Fedora lets an administrator's programs install silently. Updates still ask nothing. Installing a Flatpak runtime is the exception: Flatpak's update permission implies it, since an update may need a new runtime. Runtimes come signed from remotes already set up, and adding a remote asks.
- **A program may read the memory only of programs it started** (`kernel.yama.ptrace_scope = 1`), as on Ubuntu. Attaching a debugger to a running program, as `gdb -p` or `strace -p` do, needs root.
- **Ten wrong passwords in a row lock the account for five minutes**, at the lock screen, `sudo` and polkit alike; the lock screen shows why. Systems installed from the ISO only; see below.
- **The clipboard history lives in memory** (`$XDG_RUNTIME_DIR/cliphist`), so a password copied by hand never reaches the disk; it ends with the session. Password managers that mark what they copy as secret, such as KeePassXC, are left out of it altogether.
- **Online accounts use https only**, both when signing in and in the calendar helper.

## Text from outside

Text the shell did not write never becomes code. Shell commands get it as separate arguments (`"$1"`), never inside the command. What the launcher runs reaches Hyprland as a Lua string the text cannot leave, since a clipboard entry, which any web page can fill, may hold anything. Monitor names from a screen's EDID are quoted the same way. Notifications show plain text, with markup turned off. Addresses a Nextcloud server sends back must lead to the same server over https before the browser opens them. The welcome screen's helper, which runs as root, takes only the names of the catalog's items: what each installs, from which repository and with which key comes from files in `/usr/share/hyprdora` that only root can change, and dnf checks every package against a key pinned there rather than one fetched from the repository's own server.

## Limits

- **Hyprland's socket** lets any program of the user run commands and add keybindings, which can also record keys; GNOME has no such interface. Hyprland's permission system (`ecosystem:enforce_permissions`) is not used: it trusts programs by path, so a malicious one would run an allowed program such as `grim`.
- **Fake password windows:** any Wayland program may draw a full-screen layer that looks like the polkit prompt or the lock screen. A password prompt that appears without an action of one's own is a warning sign.
- **Saved Wi-Fi passwords** can be read by any program of the user, as in GNOME's settings.
- **Disk encryption** is chosen in the installer for each computer. Without it, a stolen laptop gives away the browser's sessions, the Wi-Fi passwords and every file; the keyring alone stays encrypted with the user's password.

## On a system installed from packages

The password limit is set by the installer. To turn it on elsewhere:

```bash
sudo sed -i -e 's/^#\? *deny *=.*/deny = 10/' -e 's/^#\? *unlock_time *=.*/unlock_time = 300/' /etc/security/faillock.conf
sudo authselect enable-feature with-faillock && sudo authselect apply-changes
```

A clipboard history kept on the disk by earlier versions can be removed after logging in again: `rm -rf ~/.cache/cliphist`.
