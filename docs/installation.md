# Installation

HyprDora installs from an ISO, or as packages on an existing Fedora 44.

## ISO

Building needs `lorax`, `pykickstart`, `createrepo_c` and `isomd5sum`, and the [Fedora Everything netinstall ISO](https://fedoraproject.org/misc/#everything) in `build/iso/source`. `mkksiso` rewrites the EFI boot image, so `make iso` asks for `sudo`.

```bash
make iso
```

The result is `build/iso/hyprdora-<version>.iso`. The installer needs a network connection and asks only for the language, keyboard, disk layout and user account. It never wipes a disk on its own. Everything else is set up automatically, and the log is in `/root/hyprdora-setup.log`.

The ISO is for your own use. It carries packages from Fedora, RPM Fusion and other vendors under their own licenses, so passing it on makes you responsible for meeting them; see [THIRD-PARTY.md](../THIRD-PARTY.md).

The installer checks no package signatures, so packages from outside Fedora come from the ISO itself. `packaging/iso/build-repo.sh` resolves the kickstart's package list against `packaging/iso/repos.repo`, downloads every package from RPM Fusion and the COPR repositories that it needs, with the drivers for every computer the kickstart's `%pre` can pick, and stops if any of them lacks a valid signature from a key in `packaging/keys`. Those keys are pinned in the repository. Fedora's own packages come from the network through metalinks, which carry checksums of the repository metadata. Downloads are kept in `build/iso/work`, so a rebuild fetches only what changed. Versions are those of the day the ISO was built; the first update brings them current.

Snapshots and the subvolumes kept out of them need a Btrfs root and are skipped on other file systems. Recovery is described in [recovery.md](recovery.md).

The installer also limits wrong passwords: ten in a row lock the account for five minutes. A system installed from packages has no such limit unless it is turned on as described in [security](security.md).

## Build packages

```bash
make rpm
```

The packages land in `build/rpm/RPMS/noarch`:

| Package | Contents |
|---|---|
| `hyprdora` | the shell, default configs, and every program the desktop needs, as dependencies |
| `hyprdora-repos` | the two COPR repositories that hold Hyprland and the cursor theme |
| `hyprdora-release` | the system's name and version, HyprDora 44, in place of `fedora-release`; numbered after Fedora's release |
| `hyprdora-logos` | HyprDora's logo where programs look for the distribution's, in place of `fedora-logos` |

Applications beyond the base, such as a browser, VS Code, Docker, ONLYOFFICE and the full codecs, are chosen on the welcome screen at the first session, followed by the default applications among those installed and chosen, or later under Applications in the settings. Each is installed from its maker's repository, added only then, with signatures checked against keys pinned in `/usr/share/hyprdora/keys`.

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

The system stays Fedora. To name it HyprDora, as the ISO does ([decision 9](decisions/0009-own-release-identity.md)), swap Fedora's release and logo packages for HyprDora's:

```bash
sudo dnf install --allowerasing ./hyprdora-release-*.rpm ./hyprdora-logos-*.rpm
```

Upgrading to a new Fedora release needs `hyprdora-release` built for it, since it replaces the package that names the release: `packaging/release/refresh.sh 45` takes the files that come from Fedora 45, and `make rpm FEDORA=45` builds the package as `hyprdora-release-45`.

## Where things go

| Path | Contents |
|---|---|
| `/usr/share/hyprdora` | shell, Hyprland config, default configs, wallpapers |
| `/etc/xdg/quickshell/hyprdora` | link that lets `qs -c hyprdora` find the shell |
| `/usr/share/wayland-sessions/hyprdora.desktop` | login session, which starts Hyprland with the packaged config |
| `/usr/lib/systemd/user/hyprdora-session.target` | activates `graphical-session.target`, which portals depend on |
| `/usr/lib/systemd/user/hyprdora-shell.service` | runs the shell and restarts it after a crash |
| `/usr/libexec/hyprdora/shell-start`, `shell-stopped` | start the shell with the chosen icon theme; end the session if the shell stops while the screen is locked |
| `/etc/pam.d/hyprdora-lock` | the lock screen's password check, the same as the console login |
| `/usr/bin/hyprdora` | recovery tool: `hyprdora rollback`, `hyprdora --help` (see [recovery](recovery.md)) |
| `/usr/libexec/hyprdora/offline-update`, `system-restore` | updates installed at restart, and system restore from the settings; run as root through pkexec, with their polkit actions in `/usr/share/polkit-1/actions` |
| `/usr/share/polkit-1/rules.d/10-hyprdora-software.rules` | installing and removing software asks for the password (see [security](security.md)) |
| `/usr/lib/sysctl.d/60-hyprdora-ptrace.conf` | a program may read only the memory of programs it started (see [security](security.md)) |
| `/usr/libexec/hyprdora/calendar` | calendar helper: the offline calendar and Nextcloud accounts |
| `/usr/libexec/hyprdora/hyprdora-portal`, `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf` | wallpaper portal backend and the portal choice that enables it |
| `/usr/libexec/hyprdora/not-metered`, `/usr/lib/systemd/system/dnf5-makecache.service.d/hyprdora-metered.conf` | the package cache is not refreshed on a metered network |
| `/etc/dnf/libdnf5-plugins/actions.d/hyprdora-snapper.actions` | a snapshot before and after every `dnf` transaction |
| `/etc/dnf/protected.d/hyprdora.conf` | stops `dnf` from removing HyprDora, snapper or `btrfs-progs` |
| `/usr/lib/systemd/system/hyprdora-hint.service` | writes the reminder of `hyprdora --help` for the console login screen and SSH at boot, in the system language |
| `/usr/lib/systemd/logind.conf.d/50-hyprdora.conf` | stops logind from powering off on a press of the power button |
| `/usr/share/plymouth/themes/hyprdora`, `/usr/libexec/hyprdora/boot-theme`, `/usr/lib/dracut/dracut.conf.d/90-hyprdora.conf` | boot splash, the hidden GRUB menu, and drivers kept out of the initramfs |
| `/usr/share/sddm/themes/Hyprdora`, `/etc/sddm.conf.d/hyprdora.conf` | login screen |
| `/usr/share/glib-2.0/schemas/90_hyprdora.gschema.override` | GTK defaults: dark theme, icons, cursor; GNOME Software without its own updates |
| `/usr/share/nautilus-python/extensions/hyprdora.py` | "Open in Terminal" in Nautilus |
| `/etc/xdg/mimeapps.list`, `/etc/xdg/xdg-terminals.list`, `/etc/alacritty/alacritty.toml` | default applications, terminal and its settings |
| `/etc/xdg/hyprland-mimeapps.list`, `/usr/libexec/hyprdora/editor-types` | every text file type (Markdown, JSON, scripts, source code) opens in the text editor; written from the MIME database at install and whenever it changes, leaving out tables, mail, playlists and other text not meant for an editor |
| `/usr/libexec/hyprdora/terminal-session`, `/etc/tmux.conf` | every Alacritty window in tmux, and tmux's settings (see [terminal](terminal.md)) |
| `/etc/xdg/nvim/sysinit.vim` | LazyVim as Neovim's default config once Neovim is installed, from `/usr/share/hyprdora/configs/nvim` |
| `/usr/libexec/hyprdora/system-setup.sh`, `first-login.sh` | system setup run by the kickstart, and the first-login step |

The session needs no files in the home directory. User files in `~/.config/hypr` and `~/.config/hyprdora` are optional and override the defaults.

## First login

The first session prepares the home directory: user folders and their bookmarks in the file manager; the shell uses the keyboard layout chosen in the installer until others are chosen in the settings. Existing files are left alone. If a step fails, the step runs again at the next login. Then the welcome screen offers applications to install.

The git identity is not set, because this step has no way to ask for it.
