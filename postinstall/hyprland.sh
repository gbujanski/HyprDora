log_info "Starting Hyprland post-install configuration..."

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

systemctl --user enable hyprpolkitagent.service
xdg-user-dirs-update

sudo systemctl enable --now power-profiles-daemon.service

log_info "Keyboard layout configuration for Hyprland..."

local sys_layout
sys_layout=$(localectl status | grep "X11 Layout" | awk '{print $3}')

if [[ -n "$sys_layout" && "$sys_layout" != "us" ]]; then
    local kb_conf="$HOME/.config/hypr/keyboard.conf"
    
    cat <<EOF > "$kb_conf"
input {
    kb_layout = $sys_layout
}
EOF

fi
