# NVIDIA-specific Wayland environment variables for Hyprland
GPU_INFO=$(lspci | grep -E "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    log_info "Configuring NVIDIA environment variables for Hyprland..."

    HYPR_ENV_FILE="$HOME/.config/hypr/env.conf"
    mkdir -p "$HOME/.config/hypr"

    cat > "$HYPR_ENV_FILE" << 'EOF'
# NVIDIA Wayland fixes
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
EOF

    log_info "NVIDIA env vars written to $HYPR_ENV_FILE"
    log_info "Remember to add: source = ~/.config/hypr/env.conf in your hyprland.conf"
fi

REPO_DIR="$(pwd)"
CONFIG_DIR="$HOME/.config"

if [ ! -d "$CONFIG_DIR" ]; then
    log_info "Creating config directory at $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

if [ -d "$CONFIG_DIR/hypr" ]; then
    log_info "Backing up existing Hypr config directory at $CONFIG_DIR/hypr"
    mv "$CONFIG_DIR/hypr" "$CONFIG_DIR/hypr_backup_$(date +%Y%m%d_%H%M%S)"
fi

log_info "Copying Hyprland configs from repository to $CONFIG_DIR"
cp -r "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

chmod +x "$CONFIG_DIR/hypr/scripts/screenshot.sh"
systemctl --user enable hyprpolkitagent.service
xdg-user-dirs-update
