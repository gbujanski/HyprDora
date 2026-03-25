if [[ "$system_update_answer" -eq 1 ]]; then
    log_info "Updating system packages..."
    sudo dnf update --refresh -yq
else
    log_info "Skipping system update."
fi