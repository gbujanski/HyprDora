app_list=(
    git                # Version control system
    curl               # Command line tool for transferring data with URLs
    wget               # Simpler command line tool for downloading files
    tar                # Standard archive utility (.tar)
    unzip              # Tool for extracting .zip archives
    p7zip              # Tool for extracting .7z and .rar archives
    pciutils           # Hardware utilities (includes 'lspci' command)
    alacritty          # Fast, GPU-accelerated terminal emulator
    neovim             # Modern, highly extensible terminal text editor
    code               # Visual Studio Code (code editor)
    zen-browser        # Lightweight web browser (Firefox fork)
    discord            # Text and voice chat application
    filezilla          # FTP client for connecting to servers
    onlyoffice         # Office suite (Word, Excel, etc.)
    VirtualBox         # Creating and managing virtual machines
    gimp               # Advanced raster graphics editor
    btop               # Beautiful terminal-based system resource monitor
    docker             # Engine for containerizing applications
    lazydocker         # Terminal UI for managing Docker
    util-linux-user    # Basic user utilities (includes 'chsh' to change shell)
    gnome-calculator   # Standard GUI calculator
    loupe              # Fast, modern GTK4 image viewer
    gnome-text-editor  # Modern GUI text editor with syntax highlighting
)

dev_languages=(
    python3
    nodejs
    java-21-openjdk-devel
    dotnet-sdk-8.0
)

log_info "Welcome to the Fedora Hyprland installation script!
This script will guide you through the installation process of Fedora with Hyprland and various applications and drivers.
You can chose manual or automatic installation. In manual mode, you can select which packages to install and whether to update the system before installation.
In automatic mode, all packages will be installed with default settings."


if [[ -n "$CLI_MODE" ]]; then
  [[ "$CLI_MODE" == "auto" ]] && manual_install_answer=1 || manual_install_answer=0
else
  manual_install_answer=$(gum confirm "Select installation mode." --affirmative="Automatic" --negative="Manual" --default="Yes" && echo 1 || echo 0)
fi

if [[ "$manual_install_answer" -eq 1 ]]; then
    log_info "You have selected Automatic installation mode. All packages will be installed with default settings."
    
    selected_apps=("${app_list[@]}")
    system_update_answer=1
else
    log_info "You have selected Manual installation mode. You will be able to select which packages to install and whether to update the system before installation."

    system_update_answer=$(gum confirm "Do you want to update the system before installing packages?" --default="Yes" && echo 1 || echo 0)
    manual_selection_answer=$(gum confirm "Do you want to manually select packages to install?" --default="No" && echo 1 || echo 0)
    dev_languages_answer=$(gum confirm "Do you want to manually select  development languages to install?" --default="No" && echo 1 || echo 0)
    games_answer=$(gum confirm "Do you want to install games stack?" --default="No" && echo 1 || echo 0)

fi

if [[ "$manual_selection_answer" -eq 1 ]]; then
    user_selection=$(gum choose --no-limit --selected="*" "${app_list[@]}")

    if [ -n "$user_selection" ]; then
        mapfile -t selected_apps <<< "$user_selection"
    fi
else
    selected_apps=("${app_list[@]}")
fi

if [[ "$dev_languages_answer" -eq 1 ]]; then
    dev_languages_selection=$(gum choose --no-limit --selected="*" "${dev_languages[@]}")

    if [ -n "$dev_languages_selection" ]; then
        mapfile -t selected_dev_languages <<< "$dev_languages_selection"
    fi
else
    selected_dev_languages=("${dev_languages[@]}")
fi

if [[ " ${selected_apps[*]} " =~ " git " ]]; then
  if [[ -n "$CLI_GH_NAME" || -n "$CLI_GH_EMAIL" || -n "$CLI_GH_MERGE" ]]; then
    git_setup=1
    [[ -n "$CLI_GH_NAME" ]] && git_username="$CLI_GH_NAME" || git_username=$(gum input --placeholder="Enter your Git username")
    [[ -n "$CLI_GH_EMAIL" ]] && git_email="$CLI_GH_EMAIL" || git_email=$(gum input --placeholder="Enter your Git email")
    [[ -n "$CLI_GH_MERGE" ]] && git_merge_type="$CLI_GH_MERGE" || git_merge_type=$(gum choose "Choose Git pull behavior:" "merge" "rebase")
  else
    manual_config_git=$(gum confirm "Do you want to configure Git right now?" --default="No" && echo 1 || echo 0)

    if [[ "$manual_config_git" -eq 1 ]]; then
      git_setup=1
      git_username=$(gum input --placeholder="Enter your Git username")
      git_email=$(gum input --placeholder="Enter your Git email")
       git_merge_type=$(gum choose "Choose Git pull behavior:" "merge" "rebase")
    else
      git_setup=0
    fi
  fi
fi
