#!/bin/bash
# Prepares the user's home on the first HyprDora login. Started by the session.
# It never replaces an existing file, and it runs again at the next login until every step succeeds.

set -uo pipefail

MARKER=${XDG_STATE_HOME:-$HOME/.local/state}/hyprdora/first-login-done

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
