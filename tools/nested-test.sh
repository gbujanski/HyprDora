#!/bin/bash
# Runs a test in a nested Hyprland with the shell from the repository, then closes it.
# Usage: [SETTINGS=file] [EMPTY_CONFIG=1] tools/nested-test.sh NAME BODY_FILE [SHELL_DIR]
#   NAME          results go to build/test/NAME: config/, shots/, hyprland.out
#   BODY_FILE     a bash file sourced once the shell answers; it can use
#                   q ARGS     the nested shell's IPC, as in `q panel open sound`
#                   W ARGS     wtype, to type or press keys, as in `W -k Escape`
#                   T R SH     the result folder, the repository, the shell folder
#                   TPID       the nested Hyprland's process
#                 screenshots: `grim "$T/shots/name.png"`, run inside the body
#   SHELL_DIR     another copy of the shell, the repository's by default
#   SETTINGS      a settings.json to start with, such as ~/.config/hyprdora/settings.json
#   STATE         a state folder to start with, such as an earlier test's build/test/NAME/state
#   EMPTY_CONFIG  start without the config folders, as on a new account
# The real session is not touched: the nested one has its own config and state folders and Wayland socket.
set -u
[ -n "${1:-}" ] && [ -f "${2:-}" ] || { sed -n '3,4p' "$0"; exit 2; }
R=$(cd "$(dirname "$0")/.." && pwd)
BODY_FILE=$(realpath "$2")
SH=$(realpath "${3:-$R/shell}")
T=$R/build/test/$1
rm -rf "$T"
mkdir -p "$T/config/hypr" "$T/config/hyprdora" "$T/shots"
[ -n "${SETTINGS:-}" ] && cp "$SETTINGS" "$T/config/hyprdora/settings.json"
if [ -n "${STATE:-}" ]; then cp -r "$(realpath "$STATE")" "$T/state"; else mkdir -p "$T/state"; fi
if [ -n "${EMPTY_CONFIG:-}" ]; then
    rm -rf "$T/config/hypr" "$T/config/hyprdora"
else
    printf 'hl.monitor({ output = "WAYLAND-1", mode = "preferred", position = "0x0", scale = 1 })\n' >"$T/config/hypr/monitors.lua"
fi

instances() { hyprctl instances -j | python3 -I -c 'import json, sys; [print(i["instance"], i["wl_socket"]) for i in json.load(sys.stdin)]'; }
before=$(instances)
cd "$R" || exit 1
XDG_CONFIG_HOME=$T/config XDG_STATE_HOME=$T/state HYPRDORA_SHELL=$SH timeout 120 Hyprland --config "$R/hypr/init.lua" >"$T/hyprland.out" 2>&1 &
# shellcheck disable=SC2034 # used by test bodies
TPID=$!
nested=""
for _ in $(seq 1 40); do
    nested=$(instances | grep -vxF "$before" | head -1)
    [ -n "$nested" ] && break
    sleep 0.25
done
[ -n "$nested" ] || { echo "the nested Hyprland did not start; see $T/hyprland.out"; exit 1; }
read -r sig socket <<<"$nested"
export HYPRLAND_INSTANCE_SIGNATURE=$sig WAYLAND_DISPLAY=$socket

q() { XDG_CONFIG_HOME=$T/config qs -p "$SH" ipc call "$@"; }
for _ in $(seq 1 40); do
    q panel current >/dev/null 2>&1 && break
    sleep 0.25
done
sleep 1

# wtype is unpacked into build/ rather than installed, as the system does not need it.
wtype_bin=$R/build/test/wtype/usr/bin/wtype
if [ ! -x "$wtype_bin" ]; then
    (mkdir -p "$R/build/test/wtype" && cd "$R/build/test/wtype" && dnf -q download wtype >/dev/null 2>&1 &&
        rpm2cpio wtype-*.rpm | cpio -idm --quiet)
fi
W() { "$wtype_bin" "$@"; }

# shellcheck source=/dev/null
. "$BODY_FILE"

XDG_CONFIG_HOME=$T/config qs -p "$SH" log 2>/dev/null | grep -E 'ERROR|TypeError|ReferenceError' | head -5
hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
