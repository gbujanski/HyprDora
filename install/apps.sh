if [ -z "$selected_apps" ]; then
    log_info "No packages selected. Skipping."
else
    if [[ " ${selected_apps[*]} " == *" code "* ]]; then
        # VsCode repository setup
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
        echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    fi
    install_packages "${selected_apps[@]}"
fi