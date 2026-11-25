#!/bin/bash
# Succeeds unless the user has paused updates in the shell's settings (see update-settings): until restart,
# for good, or until a time not yet reached. The package cache refresh runs only when it succeeds.
# With "download", it also fails while background downloads are turned off, for the background download.
#
# Usage: updates-allowed [download]
conf=/etc/hyprdora/updates.conf

value() {
    [ -f "$conf" ] && sed -n "s/^$1=//p" "$conf" | tail -n 1
}

[ -e /run/hyprdora/updates-paused ] && exit 1
[ "${1:-}" = download ] && [ "$(value download)" = off ] && exit 1
pause=$(value pause)
case "$pause" in
    always) exit 1 ;;
    '' | *[!0-9]*) exit 0 ;;
    *) [ "$(date +%s)" -ge "$pause" ] ;;
esac
