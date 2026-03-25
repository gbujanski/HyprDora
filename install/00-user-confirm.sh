app_list=(
    git
    curl
    wget
    tar
    unzip
    lspci
    alacritty
    neovim
    code
    zen-browser
    discord
    filezilla
    onlyoffice-desktopeditors
    VirtualBox
    gimp
    htop
    docker
    lazydocker
    util-linux-user
)

log_info "Welcome to the Fedora Hyprland installation script!
This script will guide you through the installation process of Fedora with Hyprland and various applications and drivers.
You can chose manual or automatic installation. In manual mode, you can select which packages to install and whether to update the system before installation.
In automatic mode, all packages will be installed with default settings."


manual_install_answer=$(gum confirm "Select installation mode." --affirmative="Automatic" --negative="Manual" --default="Yes" && echo 1 || echo 0)

if [[ "$manual_install_answer" -eq 1 ]]; then
    log_info "You have selected Automatic installation mode. All packages will be installed with default settings."
    
    selected_apps=("${app_list[@]}")
    system_update_answer=1
else
    log_info "You have selected Manual installation mode. You will be able to select which packages to install and whether to update the system before installation."

    system_update_answer=$(gum confirm "Do you want to update the system before installing packages?" --default="Yes" && echo 1 || echo 0)
    manual_selection_answer=$(gum confirm "Do you want to manually select packages to install?" --default="No" && echo 1 || echo 0)
fi

if [[ "$manual_selection_answer" -eq 1 ]]; then
    user_selection=$(gum choose --no-limit --selected="*" "${app_list[@]}")

    if [ -n "$user_selection" ]; then
        mapfile -t selected_apps <<< "$user_selection"
    fi
else
    selected_apps=("${app_list[@]}")
fi