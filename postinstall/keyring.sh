
if [ ! -d "$HOME/.local/share/keyrings" ]; then
    log_info "Creating config directory at $HOME/.local/share/keyrings"
    mkdir -p "$HOME/.local/share/keyrings"
fi

echo "Default_keyring" > "$HOME/.local/share/keyrings/default"
