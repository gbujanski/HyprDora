#!/bin/bash
# Makes the text editor the default for every text file type: text/plain and each type the shared MIME
# database derives from it, such as Markdown, JSON or a shell script. Without this, a type the editor does
# not list opens in whichever application lists it, such as Markdown in ONLYOFFICE. Left out: the types
# /etc/xdg/mimeapps.list gives to another application, and text that is not for an editor: images, sound,
# video and mail, tables (CSV stays with the spreadsheet), playlists, calendars, contacts, RTF and e-books.
# Run as root by the package on install and whenever the MIME database changes, so new formats follow.
set -eu
defaults=/etc/xdg/mimeapps.list
out=/etc/xdg/hyprland-mimeapps.list
subclasses=/usr/share/mime/subclasses

editor=$(sed -n 's|^text/plain=\([^;]*\).*|\1|p' "$defaults")
other="text/csv text/tab-separated-values text/spreadsheet application/rtf text/calendar text/vcard
    application/xspf+xml application/smil+xml application/vnd.apple.mpegurl
    application/x-fictionbook+xml application/mbox application/x-mozilla-bookmarks"
[ -n "$editor" ] && [ -r "$subclasses" ] || exit 0

# Every line of subclasses is "type parent"; the family grows until no type is added.
types=$(awk -v exclude="$(sed -n 's/=.*//p' "$defaults" | tr '\n' ' ') $other" '
    BEGIN { n = split(exclude, list, " "); for (i = 1; i <= n; i++) skip[list[i]] = 1; family["text/plain"] = 1 }
    { child[NR] = $1; parent[NR] = $2 }
    END {
        do {
            added = 0
            for (i = 1; i <= NR; i++)
                if ((parent[i] in family) && !(child[i] in family)) { family[child[i]] = 1; added = 1 }
        } while (added)
        for (type in family) if (!(type in skip) && type !~ /^(image|audio|video|message)\//) print type
    }' "$subclasses" | sort)

{
    echo "# Written by /usr/libexec/hyprdora/editor-types from the shared MIME database; changes here are lost."
    echo "# Every text type opens in the text editor of mimeapps.list. ~/.config/mimeapps.list overrides any of them."
    echo "[Default Applications]"
    for type in $types; do echo "$type=$editor"; done
} >"$out.new"
mv -f "$out.new" "$out"
