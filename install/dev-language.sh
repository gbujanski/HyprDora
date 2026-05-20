if [ -z "$selected_dev_languages" ]; then
    log_info "No packages selected. Skipping."
else
    log_info "Installing selected development language packages..."
    install_packages_dnf "${selected_dev_languages[@]}"
fi
    