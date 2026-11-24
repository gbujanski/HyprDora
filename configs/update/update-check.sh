#!/bin/bash
# Looks for updates now, when asked to in the shell, even while updates are paused or on a metered
# network: refreshes the package cache, then starts the background download, which keeps to the pause and
# the network's limits itself. Run as root through pkexec; polkit lets the active user do it without a
# password, as it changes nothing on the system.
set -u
export LC_ALL=C

dnf5 makecache --refresh --quiet || exit 1
systemctl start --no-block hyprdora-update-download.service
