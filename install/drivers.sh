log_info "Installing drivers"

GPU_INFO=$(lspci | grep -E "VGA|3D" || true)

HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL=false

log_info "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true
log_info "$GPU_INFO" | grep -qi "amd\|radeon\|advanced micro" && HAS_AMD=true
log_info "$GPU_INFO" | grep -qi "intel" && HAS_INTEL=true

if [[ "$HAS_NVIDIA" == false && "$HAS_AMD" == false && "$HAS_INTEL" == false ]]; then
    log_info "No recognized GPU found. Skipping driver installation."
fi

source install/drivers-base.sh

if [[ "${INSTALL_GAMING:-false}" == "true" ]]; then
    source install/drivers-gaming.sh
fi

if [[ "${INSTALL_VIDEO:-false}" == "true" ]]; then
    source install/drivers-video.sh
fi

if lspci -nn | grep -iq "Network controller.*Broadcom"; then
    log_info "Detected Broadcom Wi-Fi chipset. Starting installation of proprietary drivers..."

    install_packages_dnf broadcom-wl akmod-wl kernel-devel kernel-headers gcc make dkms
    
    log_info "Broadcom drivers installed successfully."
fi
