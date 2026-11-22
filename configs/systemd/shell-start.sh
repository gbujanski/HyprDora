#!/bin/bash
# Starts the shell with the icon theme chosen in the settings, which Quickshell reads once at start from
# QS_ICON_THEME. Only the themes the settings offer are passed on; anything else falls back to Papirus.
# Arguments go to qs, such as -c hyprdora or -p for a development copy. A development copy logs the
# shell's debug messages too; otherwise warnings from other components that say nothing about the shell
# are left out, such as Fedora's desktop files Quickshell cannot parse.
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
if [ "${1:-}" = -p ]; then
    rules="hyprdora.*.debug=true"
else
    rules="quickshell.desktopentry.warning=false;qt.accessibility.atspi.warning=false;quickshell.service.pipewire.node.warning=false"
fi
exec /usr/bin/qs --log-rules "$rules" "$@"
