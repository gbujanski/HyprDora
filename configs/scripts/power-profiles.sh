#!/bin/bash

swaync-client -cp

active=$(powerprofilesctl get)
available=$(powerprofilesctl list)

options=""
rofi_args=(-theme ~/.config/rofi/menu.rasi)

counter=1

if echo "$available" | grep -q "performance:"; then
    if [ "$active" == "performance" ]; then
        options+="[ *Performance ($counter) ]\n"
    else
        options+="[ Performance ($counter) ]\n"
    fi
    rofi_args+=("-kb-select-$counter" "$counter")
    ((counter++))
fi

if [ "$active" == "balanced" ]; then
    options+="[ *Balanced ($counter) ]\n"
else
    options+="[ Balanced ($counter) ]\n"
fi
rofi_args+=("-kb-select-$counter" "$counter")
((counter++))

if [ "$active" == "power-saver" ]; then
    options+="[ *Power Saver ($counter) ]\n"
else
    options+="[ Power Saver ($counter) ]\n"
fi
rofi_args+=("-kb-select-$counter" "$counter")
((counter++))

chosen=$(echo -e "$options" | sed '/^$/d' | rofi -dmenu -i "${rofi_args[@]}")

case "$chosen" in
    *Performance*) powerprofilesctl set performance ;;
    *Balanced*) powerprofilesctl set balanced ;;
    *Power\ Saver*) powerprofilesctl set power-saver ;;
esac
