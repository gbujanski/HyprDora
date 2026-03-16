# Install Hyprland and Wayland compositor dependencies
log_info "Installing Hyprland"

packages_list=(
    hyprland 
    hyprpaper
    hyprlock
    hypridle
    hyprpolkitagent
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    waybar
    wofi
    dunst
    kitty
    qt5-qtwayland
    qt6-qtwayland
    pipewire
    pipewire-pulseaudio
    wireplumber
)
install_packages "${packages_list[@]}"

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

mkdir -p "$CONFIG_DIR"

if [ -d "$CONFIG_DIR/hypr" ] && [ ! -L "$CONFIG_DIR/hypr" ]; then
    mv "$CONFIG_DIR/hypr" "$CONFIG_DIR/hypr_backup_$(date +%Y%m%d_%H%M%S)"
fi

if [ -d "$CONFIG_DIR/waybar" ] && [ ! -L "$CONFIG_DIR/waybar" ]; then
    mv "$CONFIG_DIR/waybar" "$CONFIG_DIR/waybar_backup_$(date +%Y%m%d_%H%M%S)"
fi

ln -sf "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
ln -sf "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

