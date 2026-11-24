# Third-party material

HyprDora's own code, configuration, logo and themes are under the [MIT License](LICENSE). This file lists what
the repository and its packages carry from others, and under which terms.

## Font: JetBrains Mono Nerd Font

`assets/fonts/*.ttf`, installed in `/usr/share/fonts/hyprdora`. The shell draws its text and every icon with it.

- **JetBrains Mono**: Copyright 2020 The JetBrains Mono Project Authors, under the SIL Open Font License 1.1
  ([`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)). It has no Reserved Font Name.
- **Nerd Fonts** added the icons. Its patcher is under the MIT License, Copyright 2014 Ryan L McIntyre; patched
  fonts are under the SIL Open Font License 1.1, as its license states.
- The icons come from these sets, as listed in Nerd Fonts' license audit:

| Glyph set | License |
|---|---|
| Material Design Icons (Pictogrammers), which the shell's icons come from | Apache 2.0 |
| Font Awesome (Fonticons) | CC BY 4.0 (icons) |
| Codicons (Microsoft) | CC BY 4.0 |
| Devicons | MIT |
| Font Awesome Extension | MIT |
| IEC Power Symbols | MIT |
| Octicons (GitHub) | MIT |
| Seti-UI, as modified by Nerd Fonts | MIT |
| Powerline Extra Symbols | MIT |
| Powerline Symbols | free license |
| Pomicons | SIL OFL 1.1 |
| Weather Icons | SIL OFL 1.1 |
| Font Logos | Unlicense |

Source: [Nerd Fonts license audit](https://github.com/ryanoasis/nerd-fonts/blob/master/license-audit.md) and
[license](https://github.com/ryanoasis/nerd-fonts/blob/master/LICENSE).

## Fedora's release files

`packaging/release/`: the systemd presets, dnf5's defaults, the console greeting (`issue`) and the RPM macros,
taken from Fedora's `fedora-release` package by `refresh.sh`. Copyright the Fedora Project Authors, under the
MIT License ([`packaging/release/LICENSE.fedora-release`](packaging/release/LICENSE.fedora-release)).

## lazy.nvim's start-up lines

`configs/nvim/lua/config/lazy.lua`: the lines that fetch lazy.nvim on the first start follow lazy.nvim's
documentation. lazy.nvim, by Folke Lemaitre, is under the Apache License 2.0. LazyVim and its plugins are not
in the repository; Neovim fetches them from GitHub on the first start.

## Wallpapers

`assets/hyprdora-wallpaper.jpg` and `assets/hyprdora-wallpaper-2.jpg` were generated with AI tools
(Leonardo.ai or Google Gemini). No copyright is claimed in them; they may be used without restriction, as far as
those tools' terms allow.

## Signing keys

`packaging/keys/`: the public keys of Fedora, RPM Fusion, the COPR projects HyprDora uses, Microsoft, Docker,
ONLYOFFICE and Google. They are their owners' and are included unchanged, to check the signatures of their
packages.

## Building an ISO

`make iso` downloads packages from Fedora, RPM Fusion, COPR and other vendors, each under its own license. An
ISO built this way is meant for one's own use: whoever passes it on distributes those packages, and becomes
responsible for meeting their licenses, such as offering the source of GPL software.
