#!/bin/bash
# Runs when the shell service stops. If the shell held the screen lock, the session ends and the login
# screen comes back, rather than leaving the session behind Hyprland's fallback screen for a dead lock.
marker="$XDG_RUNTIME_DIR/hyprdora/locked-$HYPRLAND_INSTANCE_SIGNATURE"
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -e "$marker" ] || exit 0
rm -f "$marker"

hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 && exit 0
# If Hyprland does not answer, logind ends the graphical session instead.
session=$(loginctl show-user "$(id -u)" -p Display --value)
[ -n "$session" ] && loginctl terminate-session "$session"
