# Installation

The ISO, which needs no manual steps, arrives in stage 5 of the [roadmap](roadmap.md). Until then, packages can be built and installed on an existing Fedora 44.

## Build

```bash
make rpm
```

The packages land in `build/rpm/RPMS/noarch`:

| Package | Contents |
|---|---|
| `hyprdora` | the shell, default configs, and every program the desktop needs, as dependencies |
| `hyprdora-repos` | the two COPR repositories that hold Hyprland and the cursor theme |
| `hyprdora-extras` | personal applications and development tools |

`hyprdora-extras` also needs the RPM Fusion, Microsoft, Docker and OnlyOffice repositories, which the kickstart enables.

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
| `/etc/alacritty/alacritty.toml`, `/etc/sddm.conf.d/hyprdora.conf` | system-wide defaults |

The session needs no files in the home directory. User files in `~/.config/hypr` and `~/.config/hyprdora` are optional and override the defaults.
