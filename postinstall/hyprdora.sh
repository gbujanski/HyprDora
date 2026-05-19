log_info "Setting up HyprDora configurations..."

REPO_DIR="$(pwd)"
CONFIG_DIR="$HOME/.config"
ASSETS_DIR="$REPO_DIR/assets"
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
HYPRDORA_DIR="$CONFIG_DIR/hyprdora"

mkdir -p "$HYPRDORA_DIR"

cp -r $REPO_DIR/configs/scripts $HYPRDORA_DIR/scripts

chmod +x $HYPRDORA_DIR/scripts/*

mkdir -p "$CONFIG_DIR/Thunar"

log_info "Setting up Thunar custom actions..."

cat << 'EOF' > ~/.config/Thunar/uca.xml
<?xml version="1.0" encoding="UTF-8"?>
<actions>
  <action>
    <icon>preferences-desktop-wallpaper</icon>
    <name>Set as wallpaper</name>
    <submenu></submenu>
    <unique-id>hyprpaper-set-wallpaper</unique-id>
    <command>~/.config/hyprdora/scripts/set-wallpaper.sh %f</command>
    <description>Set image as wallpaper via hyprpaper</description>
    <patterns>*</patterns>
    <image-files/>
  </action>
</actions>
EOF

killall thunar 2>/dev/null || true

log_info "Setting up desktop wallpaper..."

mkdir -p "$WALLPAPER_DIR"

cp "$ASSETS_DIR/hyprdora-wallpaper.jpg" "$WALLPAPER_DIR/hyprdora-wallpaper.jpg"

cat << EOF > "$CONFIG_DIR/hypr/hyprpaper.conf"
splash = false
ipc = true

wallpaper {
    monitor = 
    path = $WALLPAPER_DIR/hyprdora-wallpaper.jpg
    fit_mode = cover
}
EOF
