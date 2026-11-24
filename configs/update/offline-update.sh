#!/bin/bash
# Updates Flatpaks, downloads system updates and restarts into Fedora's offline update, which installs them
# before the system starts and then restarts or powers off. The shell's update screen shows the progress.
#
# Usage: offline-update start reboot|poweroff
#   Run as root through pkexec by the shell. Starts the download as a system service, so it does not depend
#   on the shell or the session, and passes the shell's stdin to it for commands after a failure.
# Usage: offline-update run reboot|poweroff
#   The service itself. Sleep and the lid switch are held off while it runs. Progress goes to $status as
#   JSON: { mode, state, done, total, bytes, totalBytes, message }, with state one of preparing,
#   downloading, restarting or failed. After a failure it reads one command from stdin: "retry" tries
#   again, "quit" or the end of input gives up and leaves the system as it was.
set -u

mode=${2:-}
case "$mode" in
    reboot | poweroff) ;;
    *)
        echo "usage: $0 start|run reboot|poweroff" >&2
        exit 2
        ;;
esac

export LC_ALL=C
status=/run/hyprdora/offline-update.json

case "${1:-}" in
    start)
        # A second start while one runs fails here, as the unit name is taken.
        exec systemd-run --quiet --wait --pipe --collect --unit=hyprdora-offline-update \
            --description="HyprDora update download" "$0" run "$mode"
        ;;
    run) ;;
    *)
        echo "usage: $0 start|run reboot|poweroff" >&2
        exit 2
        ;;
esac

if [ -z "${HYPRDORA_INHIBITED:-}" ]; then
    export HYPRDORA_INHIBITED=1
    exec systemd-inhibit --what=sleep:handle-lid-switch --who=HyprDora --why="Downloading updates" \
        --mode=block "$0" run "$mode"
fi

# A background download still running would hold dnf's lock; what it has downloaded so far is kept and used.
systemctl stop hyprdora-update-download.service 2>/dev/null

state=preparing done=0 total=0 bytes=0 totalBytes=0 message=""

# Writes the progress for the shell, replacing the file in one step so it never reads half of it.
write_status() {
    local text=${message//\\/\\\\}
    text=${text//\"/\\\"}
    install -d -m 755 /run/hyprdora
    printf '{"mode":"%s","state":"%s","done":%d,"total":%d,"bytes":%d,"totalBytes":%d,"message":"%s"}\n' \
        "$mode" "$state" "$done" "$total" "$bytes" "$totalBytes" "$text" >"$status.new"
    chmod 644 "$status.new"
    mv -f "$status.new" "$status"
}

# Prints a size such as 15 MiB, 685.2 MB or 12 kB in bytes. Flatpak puts a no-break space before the unit,
# so everything but letters is dropped from it.
to_bytes() {
    awk -v s="$1" 'BEGIN {
        if (!match(s, /[0-9.]+/)) { print 0; exit }
        n = substr(s, RSTART, RLENGTH); u = substr(s, RSTART + RLENGTH); gsub(/[^A-Za-z]/, "", u)
        p = index("KMGT", toupper(substr(u, 1, 1)))
        printf "%d\n", n * ((u ~ /i/) ? 1024 : 1000) ^ p
    }'
}

finish() {
    rm -f "$status" "$status.new"
}
trap finish EXIT

attempt() {
    state=preparing done=0 total=0 bytes=0 totalBytes=0 message=""
    write_status
    # Tells the shell the file is there to follow. In a subshell, so a shell no longer reading cannot end the
    # update with SIGPIPE.
    (echo started) 2>/dev/null || true

    # Everything is counted before anything downloads, so the totals on the screen stay put and match the
    # update panel. Flatpaks count as one item each, with the sizes Flathub lists; they often download less,
    # as only the changes come down.
    local apps=0 appBytes=0 size line
    while IFS=$'\t' read -r _ size; do
        apps=$((apps + 1))
        appBytes=$((appBytes + $(to_bytes "$size")))
    done < <(flatpak remote-ls --system --updates --columns=application,download-size 2>/dev/null)
    total=$apps totalBytes=$appBytes
    # The system's packages, as dnf would download them now; ones downloaded earlier are not counted.
    while IFS= read -r line; do
        if [[ $line =~ ^\ *(Installing|Upgrading|Downgrading|Reinstalling):\ +([0-9]+)\ packages? ]]; then
            total=$((total + BASH_REMATCH[2]))
        elif [[ $line =~ Need\ to\ download\ ([0-9.]+\ ?[KMGT]?i?B) ]]; then
            totalBytes=$((totalBytes + $(to_bytes "${BASH_REMATCH[1]}")))
        fi
    done < <(dnf5 upgrade --assumeno --refresh 2>&1)
    write_status

    if [ "$apps" -gt 0 ]; then
        state=downloading
        write_status
        local errors
        if ! errors=$(flatpak update --system -y --noninteractive 2>&1 >/dev/null); then
            message=$(tail -n 1 <<<"$errors")
            return 1
        fi
        done=$apps bytes=$appBytes
        write_status
    fi

    # A transaction left from an earlier attempt would be installed instead of the current updates.
    dnf5 offline clean >/dev/null 2>&1

    local downloading=0 last="" problem=""
    while IFS= read -r line; do
        last=$line
        [[ ${line,,} =~ error|failed ]] && problem=$line
        if [[ $line == "Downloading Packages:"* ]]; then
            downloading=1 state=downloading
        elif [ "$downloading" = 1 ] && [[ $line =~ 100%\ \|.*\|\ +([0-9.]+\ [KMGT]?i?B)\ \| ]]; then
            done=$((done + 1))
            bytes=$((bytes + $(to_bytes "${BASH_REMATCH[1]}")))
        else
            continue
        fi
        write_status
    done < <(dnf5 upgrade --offline -y 2>&1; echo "HYPRDORA-EXIT $?")

    if [ "$last" != "HYPRDORA-EXIT 0" ]; then
        message=${problem:-"dnf5: ${last#HYPRDORA-EXIT }"}
        return 1
    fi
    # Packages already downloaded earlier are not listed, so the count may stop short of the total.
    done=$total bytes=$totalBytes state=restarting
    write_status

    # Without packages to update there is no offline transaction, so the system just restarts or powers off.
    if dnf5 offline status 2>/dev/null | grep -qi 'no offline transaction'; then
        errors=$(systemctl "$mode" 2>&1) && return 0
    else
        local option=()
        [ "$mode" = poweroff ] && option=(--poweroff)
        errors=$(dnf5 offline reboot -y "${option[@]}" 2>&1) && return 0
    fi
    message=$(tail -n 1 <<<"$errors")
    return 1
}

while ! attempt; do
    state=failed
    write_status
    read -r command || command=quit
    [ "$command" = retry ] || exit 1
done
# The system is going down; the status stays for the screen until then.
trap - EXIT
