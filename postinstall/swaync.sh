if [ ! -d "$HOME/.config/swaync" ]; then
    log_info "Creating config directories for SwayNC"
    mkdir -p "$HOME/.config/swaync"
fi

log_info "Copying SwayNC configs from repository to $CONFIG_DIR"
cp -r "$REPO_DIR/configs/swaync" "$CONFIG_DIR/swaync"
