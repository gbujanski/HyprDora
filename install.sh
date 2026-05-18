#!/bin/bash

# Exit on error
set -e

source utils/all.sh

show_logo
echo ""

log_warning "This script requires sudo privileges. 
You may be prompted for your password."

if ! command -v gum &> /dev/null; then
	install_packages gum
fi

export GUM_CHOOSE_ORDERED=true
export GUM_CHOOSE_HEADER="Choose packages to install:
[↑/↓] Navigate   [Space] Toggle   [Enter] Confirm
(All packages are selected by default)"

source install/all.sh
source postinstall/all.sh

log_info "Installation complete!"
log_info "Reboot is highly recommended to ensure all changes take effect properly."

reboot_answer=$(gum confirm "Reboot now?" --affirmative="Yes" --negative="No" --default="Yes" && echo 1 || echo 0)

if [[ "$reboot_answer" -eq 1 ]]; then
	log_info "Rebooting..."
	sudo reboot
else
	log_info "Please remember to reboot your system as soon as possible to ensure all changes take effect properly."
fi
