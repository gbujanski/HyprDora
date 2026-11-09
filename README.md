# HyprDora

A Hyprland desktop on Fedora with a custom [Quickshell](https://quickshell.org) shell, packaged as RPMs and installed from a kickstart ISO.

**Status: early development.** The ISO is built with `make iso` and has been tested in virtual machines only. See the [roadmap](docs/roadmap.md) and [installation](docs/installation.md).

## Layout

| Path | Contents |
|---|---|
| `shell/` | Quickshell shell |
| `hypr/` | Hyprland config in Lua |
| `configs/` | rofi, alacritty, hypridle, hyprlock, hyprpaper, SDDM theme |
| `assets/` | wallpapers, bundled font |
| `packaging/` | RPM spec files |
| `kickstart/` | install description, ISO build, first-login step |
| `docs/` | documentation and decision records |

## Documentation

- [Architecture](docs/architecture.md)
- [Installation](docs/installation.md)
- [Development](docs/development.md)
- [Testing](docs/testing.md)
- [Hardware quirks](docs/hardware-quirks.md)
- [Known issues](docs/known-issues.md)
- [Decision records](docs/decisions/)

## License

[MIT](LICENSE). The bundled Nerd Font is under the SIL Open Font License, included with the font.
