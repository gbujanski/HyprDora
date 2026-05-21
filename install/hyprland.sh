# Install Hyprland and Wayland compositor dependencies
log_info "Installing Hyprland"

packages_list=(
    hyprland                     # Main Wayland window manager / compositor
    hyprpaper                    # Tool for setting desktop wallpapers
    hyprlock                     # Lock screen utility
    hypridle                     # Idle daemon (e.g., for suspending the system)
    hyprpolkitagent              # GUI prompt for sudo/admin passwords
    xdg-desktop-portal-hyprland  # Enables screen sharing for Hyprland
    xdg-desktop-portal-gtk       # Provides standard GTK file picker dialogs
    xdg-utils                    # Tools to open default applications (e.g., clicking links)
    waybar                       # Top system status bar
    rofi-wayland                 # Versatile app launcher / engine for your power menu
    swaync                       # Notification center (slide-out side panel)
    qt5-qtwayland                # Required for Qt5 (KDE) apps to run natively on Wayland
    qt6-qtwayland                # Required for Qt6 apps to run natively on Wayland
    pipewire                     # Modern audio and video server (replaces PulseAudio)
    pipewire-pulseaudio          # Compatibility layer so older apps see Pipewire as PulseAudio
    wireplumber                  # Audio session manager (manages inputs/outputs for Pipewire)
    thunar                       # Fast file manager (from XFCE)
    thunar-archive-plugin        # Thunar plugin to allow "Extract here" right-click action
    file-roller                  # GUI archive manager (often required by Thunar)
    thunar-volman                # Plugin for automatic mounting of USB drives
    papirus-icon-theme           # Beautiful, flat system icon set
    nwg-look                     # GUI application to customize GTK themes and colors
    nwg-displays                 # GUI application to manage display settings (resolution, refresh rate, etc.)
    tumbler                      # Daemon for generating thumbnails (images/videos) in Thunar
    gnome-keyring                # Secure wallet for passwords and SSH keys
    gnome-keyring-pam            # Automatically unlocks the keyring upon system login
    bluez                        # Official Linux Bluetooth protocol stack (the core daemon)
    cliphist                     # Clipboard manager that remembers copy history
    wl-clipboard                 # Command-line copy/paste utilities for Wayland
    grim                         # Utility to grab images from a Wayland compositor (screenshots)
    slurp                        # Tool to select a region in a Wayland compositor (used with grim)
    swappy                       # Lightweight image editor for sketching on screenshots
    xdg-user-dirs                # Tool to manage "well known" user directories (Pictures, Downloads, etc.)
    libnotify                    # Library for sending desktop notifications
    bibata-cursor-themes         # Mouse cursor themes
    sddm                         # Display Manager (GUI login screen)
    snapper                      # Ultimate BTRFS snapshot tool for system backups
    python3-dnf-plugin-snapper   # Automatically creates snapshots before/after DNF transactions
    btrfs-assistant              # BTRFS snapshot management tool
    power-profiles-daemon        # Daemon for managing power profiles (performance, balanced, power saver)
    NetworkManager-wifi          # Plugin allowing NM to manage wireless connections
    wpa_supplicant               # Backend daemon for WEP/WPA/WPA2/WPA3 encryption
    iw                           # CLI configuration utility for wireless devices
    nmtui                        # Text-based network manager (for Wi-Fi and Ethernet configuration in the terminal)
    wiremix                      # Graphical mixer for Pipewire (similar to pavucontrol but with more features)
    cargo                        # Rust package manager and build system (used to compile bluetui)
    dbus-devel                   # Development headers for D-Bus (required to compile bluetui)
    pkgconf                      # Tool for helping compilers find libraries (provides pkg-config)
)

packages_list_cargo=(
    bluetui                      # Minimalist TUI for managing Bluetooth connections and devices
)

install_packages_dnf "${packages_list[@]}"
install_packages_cargo "${packages_list_cargo[@]}"
