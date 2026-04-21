
if [ ! -d "$HOME/.local/share/keyrings" ]; then
    log_info "Creating config directory at $HOME/.local/share/keyrings"
    mkdir -p "$HOME/.local/share/keyrings"
fi

echo "login" > "$HOME/.local/share/keyrings/default"
