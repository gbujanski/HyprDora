if [[ "$HAS_NVIDIA" == true ]]; then
    log_info "Detected NVIDIA GPU. Installing base drivers..."

    drivers_list=(
        akmod-nvidia                  # Auto-rebuilds NVIDIA proprietary drivers on kernel updates
        xorg-x11-drv-nvidia-cuda-libs # CUDA libs for GPU compute (3D rendering, AI, encoding)
        egl-wayland                   # Crucial bridge to make Wayland (Hyprland) work on NVIDIA
        vulkan-loader                 # Base runtime required for Vulkan graphics API to work
        vulkan-tools                  # Diagnostic tools for Vulkan (includes 'vkcube', 'vulkaninfo')
        nvidia-settings               # Official GUI tool for managing NVIDIA GPU settings
    )

    install_packages_dnf "${drivers_list[@]}"

    log_info "Configuring NVIDIA kernel parameters for Wayland..."
    
    sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

    if [[ "$HAS_INTEL" == true ]]; then
        log_info "Optimus laptop detected. Installing GPU switching support..."

        install_packages_dnf "switcheroo-control"
        sudo systemctl enable --now switcheroo-control
    fi
fi

if [[ "$HAS_AMD" == true ]]; then
    log_info "Detected AMD GPU. Installing base drivers..."

    drivers_list=(
        mesa-dri-drivers              # Core open-source OpenGL drivers for AMD and Intel GPUs
        mesa-vulkan-drivers           # Open-source Vulkan drivers (RADV/ANV) for AMD and Intel
        vulkan-loader                 # Base runtime required for Vulkan graphics API to work
        vulkan-tools                  # Diagnostic tools for Vulkan (includes 'vkcube', 'vulkaninfo')
    )

    install_packages_dnf "${drivers_list[@]}"
fi

if [[ "$HAS_INTEL" == true ]]; then
    log_info "Detected Intel GPU. Installing base drivers..."

    drivers_list=(
        mesa-dri-drivers              # Core open-source OpenGL drivers for AMD and Intel GPUs
        mesa-vulkan-drivers           # Open-source Vulkan drivers (RADV/ANV) for AMD and Intel
        vulkan-loader                 # Base runtime required for Vulkan graphics API to work
        vulkan-tools                  # Diagnostic tools for Vulkan (includes 'vkcube', 'vulkaninfo')
    )

    install_packages_dnf "${drivers_list[@]}"
fi
