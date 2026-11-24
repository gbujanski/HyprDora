#!/bin/bash
# Succeeds unless the user has paused updates in the shell's settings (see update-settings): until restart,
# for good, or until a time not yet reached. The package cache refresh and the background download run only
# when it succeeds.
conf=/etc/hyprdora/updates.conf

[ -e /run/hyprdora/updates-paused ] && exit 1
pause=$([ -f "$conf" ] && sed -n 's/^pause=//p' "$conf" | tail -n 1)
case "$pause" in
    always) exit 1 ;;
    '' | *[!0-9]*) exit 0 ;;
    *) [ "$(date +%s)" -ge "$pause" ] ;;
esac
