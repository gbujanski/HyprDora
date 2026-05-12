#!/bin/bash

swaync-client -t

lock="[  Lock (l) ]"
suspend="[  Suspend (u) ]"
reboot="[ 󰑓 Reboot (r) ]"
shutdown="[  Shutdown (s) ]"
logout="[ 󰍃 Logout (e) ]"

options="$lock\n$suspend\n$reboot\n$shutdown\n$logout"

chosen=$(echo -e "$options" | rofi -dmenu -i -theme ~/.config/rofi/power.rasi)

case "$chosen" in
    "$lock") loginctl lock-session ;;
    "$suspend") systemctl suspend ;;
    "$reboot") systemctl reboot ;;
    "$shutdown") systemctl poweroff ;;
    "$logout") hyprctl dispatch exit ;;
esac
