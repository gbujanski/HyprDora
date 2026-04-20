if [ -z "$selected_apps" ]; then
    log_info "No packages selected. Skipping."
else
    for app in "${selected_apps[@]}"; do
        case "$app" in
            "code")
                # VsCode repository setup
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
                echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
                apps_to_install+=("$app")
                ;;
            "lazydocker")
                if ! command -v curl &> /dev/null; then
                    install_packages curl
                fi

                if ! command -v tar &> /dev/null; then
                    install_packages tar
                fi
                
                curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
                ;;
            "onlyoffice")
                tmp_dir=$(mktemp -d)
                rpm_url="https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors.x86_64.rpm"
                
                if ! command -v wget &> /dev/null; then
                    install_packages wget
                fi

                if wget -q --show-progress "$rpm_url" -O "$tmp_dir/onlyoffice.rpm"; then
                    install_packages "$tmp_dir/onlyoffice.rpm"
                else
                    log_error "Failed to download OnlyOffice. Skipping."
                fi

                rm -rf "$tmp_dir"
                ;;
            "zen-browser")
                if ! command -v flatpak &> /dev/null; then
                    install_packages flatpak
                fi

                sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

                sudo flatpak install -y flathub app.zen_browser.zen
                sudo flatpak install -y flathub com.github.tchx84.Flatseal
                ;;
            *)
                apps_to_install+=("$app")
                ;;
        esac
    done

    if [ ${#apps_to_install[@]} -gt 0 ]; then
        install_packages "${apps_to_install[@]}"
    fi
fi