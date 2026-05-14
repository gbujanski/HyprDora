#!/bin/bash

swaync-client -t

lock="[  Lock (l) ]"
suspend="[  Suspend (u) ]"
reboot="[ 󰑓 Reboot (r) ]"
shutdown="[  Shutdown (s) ]"
logout="[ 󰍃 Logout (e) ]"

options="$lock\n$suspend\n$reboot\n$shutdown\n$logout"

chosen=$(echo -e "$options" | rofi -dmenu -i -theme ~/.config/rofi/menu.rasi \
    -kb-select-1 "l" \
    -kb-select-2 "u" \
    -kb-select-3 "r" \
    -kb-select-4 "s" \
    -kb-select-5 "e")

case "$chosen" in
    "$lock") loginctl lock-session ;;
    "$suspend") systemctl suspend ;;
    "$reboot") systemctl reboot ;;
    "$shutdown") systemctl poweroff ;;
    "$logout") hyprctl dispatch exit ;;
esac
