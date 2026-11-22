#!/bin/bash
# Prepares the user's home on the first HyprDora login. Started by the session.
# It never replaces an existing file, and it runs again at the next login until every step succeeds.

set -uo pipefail

MARKER=${XDG_STATE_HOME:-$HOME/.local/state}/hyprdora/first-login-done

[ -e "$MARKER" ] && exit 0

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

# Nautilus lists in its sidebar only the folders bookmarked for GTK. GNOME adds the user folders with
# xdg-user-dirs-gtk; the same folders are added here, keeping bookmarks that are already there.
add_folder_bookmarks() {
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks" name dir uri
    mkdir -p "$(dirname "$file")"
    touch "$file"
    for name in DOCUMENTS MUSIC PICTURES VIDEOS DOWNLOAD; do
        dir=$(xdg-user-dir "$name")
        [ -n "$dir" ] && [ "$dir" != "$HOME" ] && [ -d "$dir" ] || continue
        uri="file://$(python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$dir")"
        grep -q "^$uri\( \|$\)" "$file" || printf '%s %s\n' "$uri" "$(basename "$dir")" >> "$file"
    done
}

status=0
xdg-user-dirs-update || status=1
add_folder_bookmarks || status=1
configure_code || status=1
install_oh_my_zsh || status=1

if [ "$status" -eq 0 ]; then
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
fi
