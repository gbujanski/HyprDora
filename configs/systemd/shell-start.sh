#!/bin/bash
# Starts the shell with the icon theme chosen in the settings, which Quickshell reads once at start from
# QS_ICON_THEME. Only the themes the settings offer are passed on; anything else falls back to Papirus.
# Arguments go to qs, such as -c hyprdora or -p for a development copy.
settings="${XDG_CONFIG_HOME:-$HOME/.config}/hyprdora/settings.json"
theme=$(python3 -I -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        print(json.load(f).get("iconTheme", ""))
except Exception:
    pass
' "$settings" 2>/dev/null)
case "$theme" in
    Papirus | Adwaita) ;;
    *) theme=Papirus ;;
esac
export QS_ICON_THEME="$theme"
exec /usr/bin/qs "$@"
