install_packages_dnf() {
    sudo dnf install -yq "$@"
}

install_packages_cargo() {
    local packages=("$@")
    
    for package in "${packages[@]}"; do
        cargo install "$package"
        sudo ln -s "$HOME/.cargo/bin/$package" "/usr/local/bin/$package"
    done
}
