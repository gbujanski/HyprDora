if [[ "$HAS_NVIDIA" == true ]]; then
    log_info "Detected NVIDIA GPU. Installing base drivers..."

    drivers_list=(
        akmod-nvidia
        xorg-x11-drv-nvidia-cuda-libs
        egl-wayland
        vulkan-loader
        vulkan-tools
        nvidia-settings
    )

    install_packages "${drivers_list[@]}"

    log_info "Configuring NVIDIA kernel parameters for Wayland..."
    sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

    if [[ "$HAS_INTEL" == true ]]; then
        log_info "Optimus laptop detected. Installing GPU switching support..."
        install_packages "switcheroo-control"
        sudo systemctl enable --now switcheroo-control
    fi
fi

if [[ "$HAS_AMD" == true ]]; then
    log_info "Detected AMD GPU. Installing base drivers..."

    drivers_list=(
        mesa-dri-drivers
        mesa-vulkan-drivers
        vulkan-loader
        vulkan-tools
    )

    install_packages "${drivers_list[@]}"
fi

if [[ "$HAS_INTEL" == true ]]; then
    log_info "Detected Intel GPU. Installing base drivers..."

    drivers_list=(
        mesa-dri-drivers
        mesa-vulkan-drivers
        vulkan-loader
        vulkan-tools
    )

    install_packages "${drivers_list[@]}"
fi