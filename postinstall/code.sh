log_info "Configuring Visual Studio Code..."

if [ ! -d "$HOME/.vscode" ]; then
    log_info "Creating config directories for VS Code"
    mkdir -p "$HOME/.vscode"
fi

cat > ~/.vscode/argv.json << 'EOF'
{
  "password-store":"gnome-libsecret"
}
EOF
