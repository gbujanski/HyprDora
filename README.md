<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo/hyprdora-logo.svg">
    <img src="assets/logo/hyprdora-logo-light.svg" alt="HyprDora" height="64">
  </picture>
</h1>

A Hyprland desktop on Fedora with a custom [Quickshell](https://quickshell.org) shell, packaged as RPMs and installed from a kickstart ISO.

**Status: early development.** Installing from COPR has been tried on a clean Fedora 44 in a virtual machine, and the ISO built with `make iso` in virtual machines. See the [roadmap](docs/roadmap.md) and [installation](docs/installation.md).

On Fedora 44:

```bash
sudo dnf copr enable gbujanski/hyprdora
sudo dnf install hyprdora-repos
sudo dnf install hyprdora
```

Then choose the HyprDora session on the login screen. An install ISO is built with `make iso`; see [installation](docs/installation.md).

## Layout

| Path | Contents |
|---|---|
| `shell/` | Quickshell shell: services, modules, shared components, translations, Python helpers |
| `hypr/` | Hyprland config in Lua |
| `configs/` | system files the package installs: login and lock screen, polkit, updates, system restore, the welcome screen's catalog, calendar helper, portal, boot splash, systemd units |
| `bin/` | `hyprdora`, the recovery tool |
| `assets/` | wallpapers, logo, bundled font |
| `packaging/` | RPM spec, release identity, pinned signing keys, the ISO's package repository and installer branding, logo script |
| `kickstart/` | install description, system setup, first-login step |
| `tools/` | development helpers, such as the nested test runner |
| `docs/` | documentation and decision records |

## Documentation

- [Architecture](docs/architecture.md)
- [Installation](docs/installation.md)
- [Recovery](docs/recovery.md)
- [Security](docs/security.md)
- [Terminal and editor](docs/terminal.md)
- [Development](docs/development.md)
- [Testing](docs/testing.md)
- [Hardware quirks](docs/hardware-quirks.md)
- [Known issues](docs/known-issues.md)
- [Decision records](docs/decisions/)
- [Roadmap](docs/roadmap.md)

## License

[MIT](LICENSE). The bundled Nerd Font, Fedora's release files and the other material from others are listed with their licenses in [THIRD-PARTY.md](THIRD-PARTY.md).
