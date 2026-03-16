install_packages() {
    sudo dnf install -yq "$@" &>/dev/null;
}
