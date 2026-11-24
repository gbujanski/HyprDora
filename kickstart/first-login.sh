#!/bin/bash
# Prepares the user's home on the first HyprDora login. Started by the session.
# It never replaces an existing file, and it runs again at the next login until every step succeeds.

set -uo pipefail

STATE=${XDG_STATE_HOME:-$HOME/.local/state}/hyprdora
MARKER=$STATE/first-login-done

# GTK 4 and libadwaita applications draw their accent, such as a main button or a focused field, in the
# shell's green rather than GNOME's nearer one; the dark text on it is the shell's too. Done once, also on
# systems set up before it came, and only where the user has no gtk.css of their own, so one removed stays
# removed. Flatpaks do not read it; they get GNOME's green through HyprDora's portal.
add_accent() {
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"
    [ -e "$STATE/accent-done" ] && return 0
    if [ ! -e "$file" ]; then
        mkdir -p "$(dirname "$file")"
        cat >"$file" <<'CSS' || return 1
/* HyprDora's accent, written once at login; change or remove it freely. */
:root {
  --accent-bg-color: #2fcf5e;
  --accent-fg-color: rgb(0 0 0 / 80%);
  --accent-color: #2fcf5e;
}
CSS
    fi
    mkdir -p "$STATE" && touch "$STATE/accent-done"
}

add_accent

[ -e "$MARKER" ] && exit 0

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

if [ "$status" -eq 0 ]; then
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
fi
