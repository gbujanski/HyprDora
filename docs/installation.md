# Installation

HyprDora installs from an ISO, or as packages on an existing Fedora 44.

## ISO

Building needs `lorax`, `pykickstart`, `createrepo_c` and `isomd5sum`, and the [Fedora Everything netinstall ISO](https://fedoraproject.org/misc/#everything) in `build/iso/source`. `mkksiso` rewrites the EFI boot image, so `make iso` asks for `sudo`.

```bash
make iso
```

The result is `build/iso/hyprdora-<version>.iso`. The installer needs a network connection and asks only for the language, keyboard, disk layout and user account. It never wipes a disk on its own. Everything else is set up automatically, and the log is in `/root/hyprdora-setup.log`.

The installer checks no package signatures, so packages from outside Fedora come from the ISO itself. `packaging/iso/build-repo.sh` resolves the kickstart's package list against `packaging/iso/repos.repo`, downloads every package from RPM Fusion, the COPR repositories, Microsoft, Docker and ONLYOFFICE that it needs, with the drivers for every computer the kickstart's `%pre` can pick, and stops if any of them lacks a valid signature from a key in `packaging/iso/keys`. Those keys are pinned in the repository. Fedora's own packages come from the network through metalinks, which carry checksums of the repository metadata. Downloads are kept in `build/iso/work`, so a rebuild fetches only what changed. Versions are those of the day the ISO was built; the first update brings them current.

Snapshots and the subvolumes kept out of them need a Btrfs root and are skipped on other file systems. Recovery is described in [recovery.md](recovery.md).

## Build packages

```bash
make rpm
```

The packages land in `build/rpm/RPMS/noarch`:

| Package | Contents |
|---|---|
| `hyprdora` | the shell, default configs, and every program the desktop needs, as dependencies |
| `hyprdora-repos` | the two COPR repositories that hold Hyprland and the cursor theme |
| `hyprdora-extras` | personal applications and development tools |

`hyprdora-extras` also needs the RPM Fusion, Microsoft, Docker and ONLYOFFICE repositories. The ISO carries their packages; the installed system gets their repositories for updates.

## Install on an existing Fedora

```bash
sudo dnf install ./hyprdora-repos-*.rpm
sudo dnf install ./hyprdora-0*.rpm
```

`dnf` pulls in all dependencies. To start the desktop at boot:

```bash
sudo systemctl enable sddm
sudo systemctl set-default graphical.target
```

Then choose the **HyprDora** session on the login screen.

## Where things go

| Path | Contents |
|---|---|
| `/usr/share/hyprdora` | shell, Hyprland config, default configs, wallpapers |
| `/etc/xdg/quickshell/hyprdora` | link that lets `qs -c hyprdora` find the shell |
| `/usr/share/wayland-sessions/hyprdora.desktop` | login session, which starts Hyprland with the packaged config |
| `/usr/lib/systemd/user/hyprdora-session.target` | activates `graphical-session.target`, which portals depend on |
| `/usr/lib/systemd/user/hyprdora-shell.service` | runs the shell and restarts it after a crash |
| `/usr/lib/systemd/logind.conf.d/50-hyprdora.conf` | stops logind from powering off on a press of the power button |
| `/usr/bin/hyprdora` | recovery tool: `hyprdora rollback`, `hyprdora --help` (see [recovery](recovery.md)) |
| `/etc/dnf/protected.d/hyprdora.conf` | stops `dnf` from removing HyprDora, snapper or `btrfs-progs` |
| `/usr/lib/systemd/system/hyprdora-hint.service` | writes the reminder of `hyprdora --help` for the console login screen and SSH at boot, in the system language |
| `/usr/libexec/hyprdora` | system setup run by the kickstart, and the first-login step |
| `/etc/xdg/mimeapps.list` | default applications |
| `/usr/libexec/hyprdora/hyprdora-portal`, `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf` | wallpaper portal backend and the portal choice that enables it |
| `/usr/share/nautilus-python/extensions/hyprdora.py` | "Open in Terminal" in Nautilus |
| `/etc/dnf/libdnf5-plugins/actions.d/hyprdora-snapper.actions` | a snapshot before and after every `dnf` transaction |
| `/etc/alacritty/alacritty.toml`, `/etc/sddm.conf.d/hyprdora.conf` | system-wide defaults |

The session needs no files in the home directory. User files in `~/.config/hypr` and `~/.config/hyprdora` are optional and override the defaults.

## First login

The first session prepares the home directory: user folders, the keyboard layout chosen in the installer, VS Code's keyring setting, and Oh My Zsh. Existing files are left alone. If a step fails, for example without a network connection, the step runs again at the next login.

The git identity is not set, because this step has no way to ask for it.
