#!/bin/bash
# Downloads system updates and restarts into Fedora's offline update, which installs them before the
# system starts and then restarts or powers off. Run as root through pkexec by the shell's power menu.
#
# Usage: offline-update reboot|poweroff
set -u

case "${1:-}" in
    reboot) option=() ;;
    poweroff) option=(--poweroff) ;;
    *)
        echo "usage: $0 reboot|poweroff" >&2
        exit 2
        ;;
esac

export LC_ALL=C

# A transaction left from an earlier attempt would be installed instead of the current updates.
dnf5 offline clean >/dev/null 2>&1

dnf5 upgrade --offline --refresh -y || exit 1

# Without packages to update there is no offline transaction, so the system just restarts or powers off.
if dnf5 offline status 2>/dev/null | grep -qi 'no offline transaction'; then
    exec systemctl "$1"
fi
exec dnf5 offline reboot -y "${option[@]}"
