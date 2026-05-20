#!/bin/bash

# Exit on error
set -e

source utils/all.sh

show_logo
echo ""

log_warning "This script requires sudo privileges. 
You may be prompted for your password."

if ! command -v gum &> /dev/null; then
	install_packages_dnf gum
fi

export GUM_CHOOSE_ORDERED=true
export GUM_CHOOSE_HEADER="Choose packages to install:
[↑/↓] Navigate   [Space] Toggle   [Enter] Confirm
(All packages are selected by default)"

CLI_MODE=""
CLI_GH_NAME=""
CLI_GH_EMAIL=""
CLI_GH_MERGE=""

for arg in "$@"; do
  case $arg in
    --mode=*)       CLI_MODE="${arg#*=}" ;;
    --gh-name=*)    CLI_GH_NAME="${arg#*=}" ;;
    --gh-email=*)   CLI_GH_EMAIL="${arg#*=}" ;;
    --gh-merge=*)   CLI_GH_MERGE="${arg#*=}" ;;
    --help)
      echo "Usage: install.sh [--mode=auto|manual] [--gh-name=NAME] [--gh-email=EMAIL] [--gh-merge=merge|rebase]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

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
