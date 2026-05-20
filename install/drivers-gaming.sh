if [[ "$games_answer" -eq 1 ]]; then
    log_info "Installing gaming packages..."

    drivers_list=(
        steam                      # Gaming platform
        lutris                     # Game manager for Epic, GOG, and older Windows games
        wine                       # Compatibility layer to run Windows apps/games on Linux
        winetricks                 # Script to install missing fonts and .dll files for Wine
        gamemode                   # Feral Interactive tool to optimize system performance for gaming
        lib32-gamemode             # 32-bit version of Gamemode for older games
        vkd3d                      # DirectX 12 to Vulkan translation layer
        vkd3d.i686                 # 32-bit version of vkd3d
        glibc.i686                 # 32-bit core system C library (required by Steam/older games)
        libstdc++.i686             # 32-bit C++ libraries
        vulkan-loader.i686         # 32-bit Vulkan loader
        mesa-vulkan-drivers.i686   # 32-bit Vulkan drivers (mostly for AMD and Intel GPUs)
    )
    install_packages_dnf "${drivers_list[@]}"
fi
