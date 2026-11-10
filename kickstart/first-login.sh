#!/bin/bash
# Prepares the user's home on the first HyprDora login. Started by the session.
# It never replaces an existing file, and it runs again at the next login until every step succeeds.

set -uo pipefail

MARKER=${XDG_STATE_HOME:-$HOME/.local/state}/hyprdora/first-login-done
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}

[ -e "$MARKER" ] && exit 0

# Copies the installer's keyboard layout into the Hyprland settings and applies it.
set_keyboard_layout() {
    local file=$CONFIG/hypr/settings.lua layout variant
    [ -e "$file" ] && return 0

    layout=$(localectl status | sed -n 's/^ *X11 Layout: *//p')
    variant=$(localectl status | sed -n 's/^ *X11 Variant: *//p')
    [ -n "$layout" ] && [ "$layout" != us ] || return 0

    mkdir -p "$CONFIG/hypr"
    printf 'hl.config({ input = { kb_layout = "%s", kb_variant = "%s" } })\n' "$layout" "$variant" > "$file"
    hyprctl reload >/dev/null
}

# Makes VS Code keep its secrets in GNOME Keyring.
configure_code() {
    command -v code >/dev/null || return 0
    [ -e "$HOME/.vscode/argv.json" ] && return 0

    mkdir -p "$HOME/.vscode"
    printf '{\n  "password-store": "gnome-libsecret"\n}\n' > "$HOME/.vscode/argv.json"
}

install_oh_my_zsh() {
    command -v zsh >/dev/null || return 0

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" || return 1
    fi
    if [ ! -e "$HOME/.zshrc" ]; then
        sed 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" > "$HOME/.zshrc"
    fi
}

status=0
xdg-user-dirs-update || status=1
set_keyboard_layout || status=1
configure_code || status=1
install_oh_my_zsh || status=1

if [ "$status" -eq 0 ]; then
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
fi
