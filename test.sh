if ! command -v gum &> /dev/null; then
    sudo dnf install -yq gum
fi

export GUM_CHOOSE_ORDERED=true
export GUM_CHOOSE_HEADER="Choose packages to install:
[↑/↓] Navigate   [Space] Toggle   [Enter] Confirm
(All packages are selected by default)"

echo "Installing base tools"

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


install_packages() {
    answer=$(gum confirm "Do you want to manually select packages to install?" --default="No" --timeout=3s && echo 1 || echo 0)

    if [[ "$answer" -eq 1 ]]; then
        selected_apps=$(gum choose --no-limit --selected="*" "$@")
    else
        selected_apps=("$@")
    fi


    if [ -z "$selected_apps" ]; then
        echo "No packages selected for installation. Skipping."
    else
        echo "Installing: ${selected_apps[@]}"
    fi
}

install_packages "${app_list[@]}"
