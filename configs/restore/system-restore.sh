#!/bin/bash
# System restore for the shell's settings, run as root through pkexec.
#   list         one snapshot per line: number, type, date (UTC), description, separated by tabs
#   create NAME  takes a snapshot of the system now
#   restore N    replaces the system with snapshot N and restarts
set -u
SNAPSHOTS=/.snapshots

case "${1:-}" in
list)
    for info in "$SNAPSHOTS"/*/info.xml; do
        [ -e "$info" ] || continue
        field() { sed -n "s:.*<$1>\(.*\)</$1>.*:\1:p" "$info" | head -1; }
        description=$(field description | sed 's/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&apos;/'"'"'/g; s/&amp;/\&/g')
        printf '%s\t%s\t%s\t%s\n' "$(basename "$(dirname "$info")")" "$(field type)" "$(field date)" "$description"
    done | sort -n
    ;;
create)
    snapper -c root create --type single --cleanup-algorithm number --description "${2:-manual}" --print-number
    ;;
restore)
    [[ "${2:-}" =~ ^[0-9]+$ ]] || exit 2
    /usr/bin/hyprdora restore "$2" && exec systemctl reboot
    ;;
*)
    echo "usage: $0 list | create NAME | restore NUMBER" >&2
    exit 2
    ;;
esac
