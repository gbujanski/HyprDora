if [[ "$git_setup" -eq 1 ]]; then
    log_info "Configuring Git global settings..."
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    git config --global pull.rebase "$git_merge_type"
fi

