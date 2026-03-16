log_info "Installing video acceleration and compute packages..."

if [[ "$HAS_NVIDIA" == true ]]; then
    log_info "Installing NVIDIA video and compute packages..."
    drivers_list=(
        xorg-x11-drv-nvidia-cuda
        libva-nvidia-driver
        ocl-icd
        opencl-headers
    )
    install_packages "${drivers_list[@]}"
fi

if [[ "$HAS_AMD" == true ]]; then
    log_info "Installing AMD video and compute packages..."
    drivers_list=(
        mesa-va-drivers
        libva
        libva-utils
        rocm-opencl
        ocl-icd
        opencl-headers
    )
    install_packages "${drivers_list[@]}"
fi

if [[ "$HAS_INTEL" == true ]]; then
    log_info "Installing Intel video and compute packages..."
    drivers_list=(
        intel-media-driver
        intel-opencl
        libva
        libva-utils
        ocl-icd
        opencl-headers
    )
    install_packages "${drivers_list[@]}"
fi