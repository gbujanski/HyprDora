if [ ! -d "$CONFIG_DIR" ]; then
    log_info "Creating config directory at $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

if [ -d "$CONFIG_DIR/waybar" ]; then
    log_info "Backing up existing Waybar config directory at $CONFIG_DIR/waybar"
    mv "$CONFIG_DIR/waybar" "$CONFIG_DIR/waybar_backup_$(date +%Y%m%d_%H%M%S)"
fi

log_info "Copying Waybar config from repository to $CONFIG_DIR"
cp -r "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

