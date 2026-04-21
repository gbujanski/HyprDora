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
    qt5-qtwayland
    qt6-qtwayland
    pipewire
    pipewire-pulseaudio
    wireplumber
    pavucontrol
    thunar
    thunar-archive-plugin
    thunar-volman
    papirus-icon-theme
    nwg-look
    tumbler
    gnome-keyring
    fuzzel
    blueman-manager
    cliphist
    bibata-cursor-themes
    sddm
)

install_packages "${packages_list[@]}"
