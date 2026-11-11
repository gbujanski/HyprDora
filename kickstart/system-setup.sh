#!/bin/bash
# Configures the installed system: repositories, drivers, personal layer, services and snapshots.
# Runs once as root from the kickstart %post, inside the new system. Takes the hyprdora-extras RPM.

set -uo pipefail

# With the graphical installer's display set, flatpak waits forever on a D-Bus autolaunch.
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY

EXTRAS_RPM=${1:?usage: system-setup.sh HYPRDORA_EXTRAS_RPM}
FEDORA=$(rpm -E %fedora)

# Runs one step and carries on after a failure, so a broken mirror cannot abort the rest of the setup.
step() {
    echo "==> $1"
    "$1" || echo "!!! step failed: $1"
}

enable_rpmfusion() {
    dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA.noarch.rpm"
}

enable_vendor_repositories() {
    cat > /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    cat > /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce-stable]
name=Docker CE Stable
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF
    cat > /etc/yum.repos.d/onlyoffice.repo <<'EOF'
[onlyoffice]
name=OnlyOffice
baseurl=https://download.onlyoffice.com/repo/centos/main/noarch/
enabled=1
gpgcheck=1
gpgkey=https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE
EOF
}

install_codecs() {
    dnf install -y --allowerasing ffmpeg &&
        dnf group install -y --allowerasing multimedia \
            --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin,libheif-freeworld
}

install_drivers() {
    local devices
    devices=$(lspci -nn)

    if grep -E 'VGA|3D|Display' <<<"$devices" | grep -qi intel; then
        dnf install -y intel-media-driver || return 1
    fi
    if grep -E 'VGA|3D|Display' <<<"$devices" | grep -qiE 'amd|radeon|advanced micro'; then
        dnf install -y --allowerasing mesa-va-drivers-freeworld || return 1
    fi
    if grep -i 'network controller' <<<"$devices" | grep -qi broadcom; then
        dnf install -y broadcom-wl akmod-wl kernel-devel || return 1
    fi
    # FaceTime HD camera in MacBooks from 2013 to 2017. Its driver and firmware tool come from a COPR.
    if grep -q '14e4:1570' <<<"$devices"; then
        dnf copr enable -y mulderje/facetimehd-kmod &&
            dnf install -y akmod-facetimehd facetimehd-firmware kernel-devel || return 1
    fi
}

# Nested in the root subvolume, so system snapshots leave out containers, virtual machine images and
# Flatpaks: they are large, change often, and rolling them back fixes nothing.
create_excluded_subvolumes() {
    [ "$(findmnt -no FSTYPE /)" = btrfs ] || return 0
    local path
    for path in /var/lib/docker /var/lib/libvirt/images /var/lib/flatpak; do
        [ -e "$path" ] && continue
        mkdir -p "$(dirname "$path")"
        btrfs subvolume create "$path" && restorecon -R "$path" || return 1
    done
}

install_extras() {
    dnf install -y "$EXTRAS_RPM"
    local result=$?
    rm -f "$EXTRAS_RPM"
    return "$result"
}

install_flatpaks() {
    flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo &&
        flatpak install --system --noninteractive flathub app.zen_browser.zen com.github.tchx84.Flatseal
}

configure_snapshots() {
    [ "$(findmnt -no FSTYPE /)" = btrfs ] || return 0
    snapper --no-dbus -c root create-config / || return 1
    # Quota lets snapper measure snapshots, so the space limits below can be enforced.
    snapper --no-dbus -c root setup-quota || return 1
    # Snapshots use at most 10% of the disk and leave at least 20% free; ranges let the cleanup go down to 2.
    snapper --no-dbus -c root set-config \
        TIMELINE_LIMIT_HOURLY=0 TIMELINE_LIMIT_DAILY=3 TIMELINE_LIMIT_WEEKLY=2 \
        TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
        NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=2-4 \
        SPACE_LIMIT=0.1 FREE_LIMIT=0.2 || return 1
    systemctl enable snapper-timeline.timer snapper-cleanup.timer
}

enable_keyring_login() {
    authselect enable-feature with-pam-gnome-keyring && authselect apply-changes
}

enable_services() {
    systemctl enable sddm bluetooth power-profiles-daemon cups docker
    systemctl set-default graphical.target
}

configure_users() {
    useradd -D -s /bin/zsh >/dev/null
    local admins user
    admins=$(getent group wheel | cut -d: -f4 | tr ',' ' ')
    for user in $admins; do
        usermod -s /bin/zsh -aG docker "$user"
    done
}

step enable_rpmfusion
step enable_vendor_repositories
step install_codecs
step install_drivers
step create_excluded_subvolumes
step install_extras
step install_flatpaks
step configure_snapshots
step enable_keyring_login
step enable_services
step configure_users
