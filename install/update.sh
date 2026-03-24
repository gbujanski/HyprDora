answer=$(gum confirm "Do you want to update the system before installing packages?" --default="Yes" --timeout=3s && echo 1 || echo 0)

if [[ "$answer" -eq 1 ]]; then
    log_info "Updating system packages..."
    sudo dnf update --refresh -yq
else
    log_info "Skipping system update."
fi