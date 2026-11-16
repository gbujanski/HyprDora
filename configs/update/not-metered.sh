#!/bin/bash
# Succeeds unless the current connection is metered, which NetworkManager reports as 1 (yes) or 3 (guessed
# yes): a phone hotspot, or a network marked as metered in the shell. Background downloads such as
# dnf5-makecache run only when it succeeds. Without NetworkManager nothing is known, so they run.
state=$(busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager \
    org.freedesktop.NetworkManager Metered 2>/dev/null)
case "$state" in
    "u 1" | "u 3") exit 1 ;;
    *) exit 0 ;;
esac
