# 9. HyprDora's own name in os-release and the installer

**Context.** The ISO combines Fedora with software from outside it (RPM Fusion, COPR repositories, HyprDora's own packages), which makes it a Fedora Remix. Fedora's trademark guidelines ask remixes to leave out `fedora-release`, `fedora-logos` and `fedora-release-notes`, and not to use the Fedora logo. Fedora's own replacements, `generic-release` and `generic-logos`, are placeholders: their os-release names the system "Generic" with joke addresses, and their systemd presets lag Fedora's (in Fedora 44 they leave `wireplumber`, `pipewire-pulse` and `systemd-resolved` off, which would take sound and DNS from a fresh install).

**Decision.** Two packages of HyprDora's own, built from the same spec:

- `hyprdora-release`, at Fedora's release number, which dnf reads as `$releasever`. Its os-release names the system "HyprDora 44" with `ID=hyprdora` and `ID_LIKE=fedora`. Everything else comes from Fedora unchanged: the systemd presets, dnf5's defaults (signature checks on), the console greeting and the RPM macros, `%fedora` and `%dist` among them, which akmods use to build drivers on the computer. `packaging/release/refresh.sh` takes these files from a new Fedora release. `/etc/fedora-release` and `/etc/redhat-release` stay, pointing at HyprDora's release file, because scripts written for Fedora look for them.
- `hyprdora-logos`, which gives programs that ask for the distribution's logo HyprDora's.

The installer stays Fedora's, with a `product.img` that names it HyprDora and puts HyprDora's logo and colours in place of Fedora's, an Anaconda profile based on Fedora's, and boot entries that name HyprDora.

The `hyprdora` package does not require either package, so it can still be installed on an existing Fedora, which then stays Fedora.

**Rejected.**
- `generic-release` and `generic-logos`, for the reasons above.
- Keeping `ID=fedora` and changing only the name. Tools would keep working without any change, but the system would still present itself as Fedora, which the guidelines are meant to prevent.

**Consequence.** Tools that check `ID=fedora` without reading `ID_LIKE` do not recognise the system; Ultramarine, which made the same choice, lists `dnf copr enable` and some vendors' install scripts among them. `dnf copr` reads the distribution from `/usr/share/dnf/plugins/copr.vendor.conf`, which `hyprdora-release` sets to Fedora, so it picks Fedora's builds (verified in a VM); vendors' scripts remain as they are. HyprDora's own repositories are written with fixed addresses and are not affected. Each new Fedora release needs `hyprdora-release` rebuilt for it before upgrading.
