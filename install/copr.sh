log_info "Adding RPM Fusion repositories"

install_packages "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
install_packages "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

sudo dnf copr enable -yq sdegler/hyprland
sudo dnf copr enable -yq peterwu/rendezvous