
#!/bin/bash

# Exit on error
set -e

source utils/loger.sh
source utils/installer.sh

log_warning "This script requires sudo privileges. 
You may be prompted for your password."

if ! command -v gum &> /dev/null; then
	install_packages gum
fi

export GUM_CHOOSE_ORDERED=true
export GUM_CHOOSE_HEADER="Choose packages to install:
[↑/↓] Navigate   [Space] Toggle   [Enter] Confirm
(All packages are selected by default)"

source install/00-user-confirm.sh
source install/update.sh
source install/copr.sh
source install/apps.sh
source install/zsh.sh
source install/drivers.sh
source install/hyprland.sh

log_info "Installation complete!
You can continue with further configuration."
