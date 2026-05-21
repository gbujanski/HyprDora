# HyprDora

> Fedora + Hyprland. One script. No bloat. All yours.

HyprDora is an automated setup script that takes a fresh **Fedora Everything (netinst)** install and turns it into a fully configured Hyprland desktop — optimized to stay out of your way and leave system resources for actual work.

Start from `Fedora-Everything-netinst-x86_64-43-1.6`, run the script, and you're done.

---

## Table of contents

- [Demo](#demo)
- [Why this exists](#why-this-exists)
- [The philosophy](#the-philosophy)
- [What it looks like](#what-it-looks-like)
- [The login screen](#the-login-screen)
- [Requirements](#requirements)
- [Installation](#installation)
- [Keybindings](#keybindings)
- [Stack](#stack)
- [Customization](#customization)
- [GPU drivers](#gpu-drivers)
- [Contributing & issues](#contributing--issues)
- [Under the hood](#under-the-hood)
- [Backups](#backups)
- [Status](#status)
- [Notes](#notes)

---

## Demo

[![HyprDora demo](https://img.youtube.com/vi/q2wIz--xOu0/maxresdefault.jpg)](https://youtu.be/q2wIz--xOu0)

39 seconds: script launch → reboot → login → btop → swaync → power menu → shutdown. The install itself takes around 5 minutes — that part's sped up, because watching packages download is nobody's idea of a good time.

---

## Why this exists

Modern desktop environments are getting heavier with every release. GNOME, KDE, and their cousins look great — but they also eat through RAM and CPU just to sit idle. On older or low-spec hardware, that's a problem. On any hardware, it's wasted potential.

HyprDora was built around one idea: **the system should serve you, not the other way around.**

Idle resource usage hovers around **~900 MB RAM and ~1–2% CPU**. The rest is yours.

---

## The philosophy

**Performance first.** No visual noise, no unnecessary background processes, no "smart" features you didn't ask for. The desktop is a tool, not a show.

**Minimalism with purpose.** Everything visible on screen earns its place. If it doesn't help you work, it's not there.

**Stability over bleeding edge.** Fedora was chosen specifically because updates go through Red Hat's QA process before they reach you. No rolling-release roulette where a routine update breaks your system.

---

## What it looks like

The visual language is consistent throughout — a deliberate `[ LABEL ]` bracket style that runs from the status bar all the way into the login screen. Think old terminal. Think DOS. Think the computer from the hatch in *Lost*.

### The bar

Waybar stays minimal:

- **Left** — virtual workspaces `[1] [2] [3] [4] [5]`
- **Center** — weather, date, time
- **Right** — `[ VOL: 44% ]` `[ CPU: 2% ]` `[ RAM: 22% ]` + notification icon

That's it. No now-playing widget, no calendar pop-up, no system tray cluttered with icons. The notification dot on the right lights up when something needs attention.

### The control panel

Clicking the notification icon opens **swaync**, which doubles as a control center. It's where the things you don't want under a keyboard shortcut live — Wi-Fi, Bluetooth, Power Mode, display settings, audio source and microphone toggle. There's also a power button that opens the power menu.

### The power menu

The power menu is **rofi** — keyboard-driven, no confirmation dialogs:

| Action | Shortcut |
|---|---|
| `Lock` | `l` |
| `Suspend` | `u` |
| `Reboot` | `r` |
| `Shutdown` | `s` |
| `Logout` | `e` |


Press `s` — the machine shuts down. No Enter, no "are you sure?". The letter in brackets is the shortcut.

---

## The login screen

This is where it gets interesting.

When the machine boots, you see: a black screen, a green `>:` prompt, and a blinking cursor. That's all.

No username field. No password field. No hint text. Just the cursor.

You type your username and press Enter. The text clears. The `>:` reappears with the cursor blinking — same as before. You type your password (nothing echoes, same as any Linux terminal). Press Enter. You're in.

If you get the credentials wrong, the green text turns red for one second. Then it resets. No error message. No explanation. Just red, then back to black.

**The system also accepts commands** at the login prompt. Prefix with `/`:

| Command | Action |
|---|---|
| `/help` | Show available commands |
| `/poweroff` | Shut down the machine |
| `/reboot` | Reboot |
| `/suspend` | Suspend |

Type `/help` instead of your username and you'll see the full command list. This is how power management works before you've logged in, without adding any buttons to the screen.

---

## Requirements

- Fresh install of `Fedora-Everything-netinst-x86_64-43-1.6`
- Internet connection during setup
- That's it

---

## Installation

```bash
sudo dnf install -y git
git clone https://github.com/gbujanski/HyprDora.git
cd hyprdora
chmod +x install.sh
./install.sh
```

The script handles everything: package installation, Hyprland configuration, Waybar, swaync, the login screen, theming, and your default application stack. It may ask for your password early on — that's just sudo doing its thing.

### Modes

The script starts by asking how you want to proceed:

**Auto** — sensible defaults, no questions asked. System update, no extra app selection, no programming languages prompt, no gaming packages, Git config prompt still appears (see below).

**Manual** — you decide step by step:

| Prompt | Default |
|---|---|
| Update system before install? | Yes |
| Choose which apps to install? | No |
| Choose programming languages to install? | No |
| Install gaming package (Steam + drivers)? | No |

The gaming package is opt-in by default — the whole point of this setup is performance, not eye candy. But running two maps in Path of Exile after work is a perfectly valid life choice.

### Git configuration

Regardless of mode, the script will ask if you want to configure Git (name, email, merge strategy). It's separated from everything else because you might want full auto mode but still set up Git — or not. Your call.

If you skip the Git questions interactively, you can always configure it via flags instead.

### Flags

Run the script fully non-interactively by passing everything upfront:

```bash
./install.sh --mode=auto --gh-name=your_name --gh-email=your@email.com --gh-merge=rebase
```

```
Usage: install.sh [--mode=auto|manual] [--gh-name=NAME] [--gh-email=EMAIL] [--gh-merge=merge|rebase]
```

Partial Git flags work too — if you pass `--gh-name` but forget `--gh-email`, the script assumes you want Git configured and will ask only for what's missing.

---

## Keybindings

Hyprland config is split into multiple files. Keybindings live in one place:

```bash
cat ~/.config/hypr/hyprland_keybindings.conf
```

Or grep for something specific:

```bash
grep "terminal" ~/.config/hypr/hyprland_keybindings.conf
```

If you're not logged in yet or just want a quick reference, [the file is readable directly in the repo](https://github.com/gbujanski/HyprDora/blob/main/configs/hypr/hyprland_keybindings.conf).

No dedicated shortcut viewer, no GUI cheat sheet — a terminal and `cat` is all you need. If you can't open a terminal yet, you probably need to read the keybindings file first anyway.

---

## Stack

The core of what makes this work:

| Component | Role |
|---|---|
| Hyprland | Wayland compositor / window manager |
| Waybar | Status bar |
| swaync | Notification center + control panel |
| hyprlock | Lock screen |
| hyprpaper | Wallpaper |
| SDDM | Login manager |
| rofi | App launcher, power menu |
| Snapper + btrfs-assistant | Automatic snapshots and backup management |

Everything else — browsers, office suite, image tools, dev utilities — is listed with comments explaining what each package does in [`install/00-user-confirm.sh`](https://github.com/gbujanski/HyprDora/blob/main/install/00-user-confirm.sh) and [`install/hyprland.sh`](https://github.com/gbujanski/HyprDora/blob/main/install/hyprland.sh). That's the source of truth. The README won't try to stay in sync with it.

---

## Customization

HyprDora is built around a specific set of choices — Zen Browser instead of Firefox or Chrome, a particular app stack, a particular look. These are deliberate decisions, not placeholders.

**Swapping apps** is straightforward. The application list lives in [`install/00-user-confirm.sh`](https://github.com/gbujanski/HyprDora/blob/main/install/00-user-confirm.sh) — edit the array, done. Or just use manual mode during install and deselect what you don't want.

**Don't touch** [`install/hyprland.sh`](https://github.com/gbujanski/HyprDora/blob/main/install/hyprland.sh) unless you know what you're doing — it contains the core libraries that make the whole thing work. Breakage there means no desktop.

If the defaults don't fit your workflow, the MIT license is there for a reason. Fork it, make it yours.

## GPU drivers

The script detects your hardware automatically and installs the right drivers:

- Intel
- AMD
- NVIDIA
- Intel + NVIDIA (hybrid)

No manual driver selection needed.

## Contributing & issues

Feedback is welcome — if something's broken or you have a suggestion, open an issue.

That said, HyprDora is opinionated by design. Feature requests like "add Chrome instead of Zen Browser" or "include app X by default" are unlikely to be merged — the point is a curated, lean setup, not a universal installer. If the defaults don't match your needs, fork it and make it yours. That's what the [MIT license](https://github.com/gbujanski/HyprDora/blob/main/LICENSE) is for.

---

## Under the hood

Building on a minimal Fedora netinst means starting from almost nothing — and "almost nothing" turns out to include a surprising number of things you never think about when installing GNOME or KDE, because they come pre-bundled.

A few things that needed solving:

**Keyring.** Without configuration, apps that need credential storage (browsers, keychain-backed tools) will pop up a password prompt every time after login. HyprDora configures PAM via `authselect` to unlock the GNOME keyring automatically through SDDM — so it just works, silently, in the background.

**Default folders.** A fresh minimal install has no `~/Pictures`, `~/Documents`, `~/Downloads` and so on. Without `xdg-user-dirs`, nothing creates them. Without `xdg-utils`, the system has no concept of which app should open which file type. Both are included and configured.

**Image viewer.** Not included by default. Neither is a text editor or a calculator. These feel like they should just be there — they're not. HyprDora pulls in `loupe` (image viewer), `gnome-text-editor`, and `gnome-calculator` so you're not discovering their absence one by one.

**Screenshots.** Two keybindings, one script:

| Shortcut | Action |
|---|---|
| `Print` | Full screenshot |
| `Shift + Print` | Area selection |

Screenshots are saved to `~/Pictures/Screenshots/` with a timestamp, copied to clipboard automatically, and a notification appears with an option to open the file in Swappy for quick annotation.

**Power profiles.** `power-profiles-daemon` is included and exposed in swaync — switch between balanced, power-save, and performance without touching a terminal.

**Wi-Fi.** This one's on you — there's no GUI network manager. You'll need to connect via terminal (`nmcli`) at least once on first boot. It's the most "Linux-y" friction point in the whole setup and a known gap.

**Known limitation worth mentioning:** double-clicking a JPEG currently opens GIMP. MIME type defaults need work and are on the list — it's not critical, but it's not right either.

The honest answer to "is everything covered?" is: probably not. Hyprland doesn't come with a settings app. Every default that GNOME or KDE handle silently is a decision someone has to make explicitly here. Most of them are made for you by the script — but it's a Wayland compositor with a config file, not a consumer OS. Expect occasional rough edges, especially on hardware that hasn't been tested yet.

## Backups

Snapper is configured out of the box on a BTRFS filesystem — no setup needed. The snapshot policy keeps:

- Daily snapshots for the last **7 days**
- **1 weekly** snapshot

`btrfs-assistant` is included if you want a GUI to browse or restore snapshots.

---

## Status

Currently at **v0.x** — it works, it's usable, but there's still cleanup to do (mainly separating core system packages from optional ones so the distinction is cleaner). Consider it stable enough to use, not polished enough to call 1.0.

This is also a living project. HyprDora is the system I actually use — so it gets updated when something bothers me, when I find a better approach, or when I discover yet another thing that "obviously should just work" and doesn't. Expect changes.

---

## Notes

This setup was built and tested on a **2014 MacBook Air (A1466)** — a machine Apple dropped support for years ago. On hardware this old, GNOME and KDE were painful. HyprDora made it usable again.

If it works there, it works anywhere.

---

[MIT License](https://github.com/gbujanski/HyprDora/blob/main/LICENSE)