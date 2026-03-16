
#!/bin/bash

# Exit on error
set -e

source utils/loger.sh
source utils/installer.sh

log_warning "This script requires sudo privileges. You may be prompted for your password."

source install/base.sh
source install/copr.sh
source install/update.sh
source install/drivers.sh
source install/hyprland.sh
source install/apps.sh

log_info "Installation complete! You can continue with further configuration."
