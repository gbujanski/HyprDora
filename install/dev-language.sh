if [ -z "$selected_dev_languages" ]; then
    log_info "No packages selected. Skipping."
else
    install_packages "${selected_dev_languages[@]}"
fi
    