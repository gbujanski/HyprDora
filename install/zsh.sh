log_info "Installing Zsh and Oh My Zsh..."

install_packages_dnf "zsh"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc
fi

log_info "Installing Nerd Font..."
font_name="JetBrainsMono"

font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

font_dir="$HOME/.local/share/fonts/${font_name}NerdFont"

if [ -d "$font_dir" ]; then
    log_info "Nerd Font already installed. Skipping."
else 
    tmp_dir=$(mktemp -d)

    if curl -fsSL "$font_url" -o "$tmp_dir/${font_name}.zip"; then

        mkdir -p "$font_dir"
        
        if unzip -q "$tmp_dir/${font_name}.zip" -d "$font_dir"; then
            if [ -n "$(ls -A "$font_dir")" ]; then
                log_info "Nerd Font installed successfully."
            else
                log_error "Unzip succeeded but folder is empty!"
            fi
        fi
        
        fc-cache -f "$font_dir"
    else 
        log_info "Failed to download Nerd Font. Skipping."
    fi

    rm -rf "$tmp_dir"
    log_info "Nerd Font installation complete."
fi

if [ "$(basename "$SHELL")" != "zsh" ]; then
    log_info "Changing default shell to Zsh..."
    sudo usermod -s "$(which zsh)" "$USER"
else
    log_info "Zsh is already the default shell. Skipping."
fi

log_info "Zsh installation complete."