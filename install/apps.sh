log_info "Installing desktop applications"

# VsCode repository setup
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

apps_list=(
    alacritty
    code
    zen-browser
    discord
    filezilla
    onlyoffice-desktopeditors
    VirtualBox
    gimp
)

install_packages "${apps_list[@]}"
