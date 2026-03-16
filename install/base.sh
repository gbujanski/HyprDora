log_info "Installing base tools"

app_list=(
    git
    neovim
    curl
    wget
    tar
    unzip
    htop
    lspci
)

install_packages "${app_list[@]}"