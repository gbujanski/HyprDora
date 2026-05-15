#!/bin/bash

if [ -z "$1" ]; then
    echo "File does not exist!"
    exit 1
fi

IMAGE_PATH="$1"
CONF_FILE="$HOME/.config/hypr/hyprpaper.conf"

hyprctl hyprpaper wallpaper ",$IMAGE_PATH,cover"

cat << EOF > "$CONF_FILE"
splash = false
ipc = true

wallpaper {
    monitor = 
    path = $IMAGE_PATH
    fit_mode = cover
}
EOF

hyprctl hyprpaper unload unused
