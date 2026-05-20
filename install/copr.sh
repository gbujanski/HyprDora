log_info "Adding RPM Fusion repositories"

install_packages_dnf "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" &> /dev/null;
install_packages_dnf "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" &> /dev/null;

log_info "Adding Copr repositories for Hyprland and related packages"
sudo dnf copr enable -yq sdegler/hyprland &> /dev/null;
sudo dnf copr enable -yq peterwu/rendezvous &> /dev/null;
sudo dnf copr enable -y tofik/nwg-shell &> /dev/null;
