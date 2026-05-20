if [[ "$HAS_NVIDIA" == true ]]; then
    log_info "Installing NVIDIA video and compute packages..."
    drivers_list=(
        xorg-x11-drv-nvidia-cuda # Core CUDA compute libraries for NVIDIA
        libva-nvidia-driver      # VA-API wrapper for hardware video acceleration on NVIDIA
        ocl-icd                  # OpenCL ICD loader (base requirement for OpenCL)
        opencl-headers           # C header files for OpenCL API
    )
    install_packages_dnf "${drivers_list[@]}"
fi

if [[ "$HAS_AMD" == true ]]; then
    log_info "Installing AMD video and compute packages..."
    drivers_list=(
        mesa-va-drivers          # VA-API drivers for hardware video acceleration on AMD
        libva                    # Core Video Acceleration API library
        libva-utils              # Diagnostic tools for VA-API (includes 'vainfo')
        rocm-opencl              # AMD's official OpenCL compute implementation (ROCm)
        ocl-icd                  # OpenCL ICD loader (base requirement for OpenCL)
        opencl-headers           # C header files for OpenCL API
    )
    install_packages_dnf "${drivers_list[@]}"
fi

if [[ "$HAS_INTEL" == true ]]; then
    log_info "Installing Intel video and compute packages..."
    drivers_list=(
        intel-media-driver       # VA-API driver for hardware video acceleration on Intel GPUs
        intel-opencl             # Intel's official OpenCL compute implementation
        libva                    # Core Video Acceleration API library
        libva-utils              # Diagnostic tools for VA-API (includes 'vainfo')
        ocl-icd                  # OpenCL ICD loader (base requirement for OpenCL)
        opencl-headers           # C header files for OpenCL API
    )
    install_packages_dnf "${drivers_list[@]}"
fi