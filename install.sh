
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

log_info "Installation complete!
You can continue with further configuration."
