if [[ "$games_answer" -eq 1]]; then
    log_info "Installing gaming packages..."

    drivers_list=(
        steam
        lutris
        wine
        winetricks
        gamemode
        lib32-gamemode
        vkd3d
        vkd3d.i686
        glibc.i686
        libstdc++.i686
        vulkan-loader.i686
        mesa-vulkan-drivers.i686
    )
    install_packages "${drivers_list[@]}"
fi
