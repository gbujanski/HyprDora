#!/bin/bash
# Changes how the system looks for updates, for the shell's Updates settings. Run as root through pkexec,
# which asks for the administrator password: pausing turns off every automatic check and download for the
# whole computer.
#
# Usage: update-settings pause restart|always|SECONDS
#          restart  until the computer restarts; always  until resumed; SECONDS  for that long from now
#        update-settings resume
#        update-settings interval often|daily|weekly
#          often  10 minutes after start and every 3 hours after (Fedora's own timer); daily, weekly  once a
#          day or a week, caught up at start when missed
#        update-settings download on|off
#          whether updates download in the background; they are still looked for
#
# The settings are in $conf as key=value lines, which the shell reads too: pause=always or pause=END, END in
# seconds since the epoch, interval=daily or weekly, and download=off. A pause until restart is a file in
# /run, which a restart clears. updates-allowed checks the pause and the download for the services.
set -u

conf=/etc/hyprdora/updates.conf
restart_pause=/run/hyprdora/updates-paused
timer_dropin=/etc/systemd/system/dnf5-makecache.timer.d/hyprdora-interval.conf

usage() {
    echo "usage: $0 pause restart|always|SECONDS | resume | interval often|daily|weekly | download on|off" >&2
    exit 2
}

# Sets one key, keeping the others; an empty value leaves the key out, for its default. Written in one step,
# so the shell never reads half of it.
set_key() {
    install -d -m 755 "${conf%/*}"
    {
        echo "# Written by the shell's Updates settings through /usr/libexec/hyprdora/update-settings."
        [ -f "$conf" ] && grep -v -e '^#' -e "^$1=" "$conf"
        [ -n "$2" ] && echo "$1=$2"
    } >"$conf.new"
    chmod 644 "$conf.new"
    mv -f "$conf.new" "$conf"
}

case "${1:-}" in
    pause)
        case "${2:-}" in
            restart)
                install -d -m 755 "${restart_pause%/*}"
                echo restart >"$restart_pause"
                set_key pause ""
                ;;
            always)
                rm -f "$restart_pause"
                set_key pause always
                ;;
            '' | *[!0-9]*) usage ;;
            *)
                rm -f "$restart_pause"
                set_key pause "$(($(date +%s) + $2))"
                ;;
        esac
        # A download already under way stops too.
        systemctl stop hyprdora-update-download.service 2>/dev/null
        ;;
    resume)
        rm -f "$restart_pause"
        set_key pause ""
        ;;
    interval)
        case "${2:-}" in
            often)
                rm -f "$timer_dropin"
                set_key interval ""
                ;;
            daily | weekly)
                install -d -m 755 "${timer_dropin%/*}"
                printf '%s\n' "# Written by /usr/libexec/hyprdora/update-settings: look for updates $2." \
                    "[Timer]" "OnBootSec=" "OnUnitInactiveSec=" "OnCalendar=$2" "Persistent=true" >"$timer_dropin"
                set_key interval "$2"
                ;;
            *) usage ;;
        esac
        systemctl daemon-reload
        systemctl restart dnf5-makecache.timer
        ;;
    download)
        case "${2:-}" in
            on) set_key download "" ;;
            off)
                set_key download off
                systemctl stop hyprdora-update-download.service 2>/dev/null
                ;;
            *) usage ;;
        esac
        ;;
    *) usage ;;
esac
