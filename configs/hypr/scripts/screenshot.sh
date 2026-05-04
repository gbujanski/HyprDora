#!/bin/bash

PICTURES_DIR=$(xdg-user-dir PICTURES)
SCREENSHOT_DIR="$PICTURES_DIR/Screenshots"

mkdir -p "$SCREENSHOT_DIR"

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
FILE="$SCREENSHOT_DIR/$TIMESTAMP.png"

if [ "$1" == "full" ]; then
    grim "$FILE"
else
    grim -g "$(slurp)" "$FILE" || exit 1
fi

wl-copy < "$FILE"

ACTION=$(notify-send "Screenshot Captured" "Saved to Screenshots folder" \
    -a "Hyprland" \
    -h "string:image-path:$FILE" \
    --action="edit=Edit with Swappy")

if [ "$ACTION" == "edit" ]; then
    swappy -f "$FILE"
fi
