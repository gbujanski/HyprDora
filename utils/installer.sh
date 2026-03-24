install_packages() {
    sudo dnf install -yq "$@"
}

install_selected_packages() {
    local answer=$(gum confirm "Do you want to manually select packages to install?" --default="No" --timeout=3s && echo 1 || echo 0)

    if [[ "$answer" -eq 1 ]]; then
        selected_apps=$(gum choose --no-limit --selected="*" "$@")
    else
        selected_apps=("$@")
    fi

    if [ -z "$selected_apps" ]; then
        log_info "No packages selected. Skipping."
    else
        install_packages "${selected_apps[@]}"
    fi
}

