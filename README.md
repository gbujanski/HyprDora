<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo/hyprdora-logo.svg">
    <img src="assets/logo/hyprdora-logo-light.svg" alt="HyprDora" height="64">
  </picture>
</h1>

A Hyprland desktop on Fedora with a custom [Quickshell](https://quickshell.org) shell, packaged as RPMs and installed from a kickstart ISO.

**Status: early development.** The ISO is built with `make iso` and has been tested in virtual machines only. See the [roadmap](docs/roadmap.md) and [installation](docs/installation.md).

## Layout

| Path | Contents |
|---|---|
| `shell/` | Quickshell shell |
| `hypr/` | Hyprland config in Lua |
| `configs/` | alacritty, hypridle, hyprpaper, SDDM theme, PAM for the lock screen |
| `assets/` | wallpapers, logo, bundled font |
| `packaging/` | RPM spec files, the script that draws the logo |
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
