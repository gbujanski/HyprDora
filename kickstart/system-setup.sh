#!/bin/bash
# Configures the installed system: repositories for later updates, Flatpaks, services and snapshots.
# Runs once as root from the kickstart %post, inside the new system. Packages, drivers and codecs included,
# come from the installer's own package step, out of the ISO.

set -uo pipefail

# With the graphical installer's display set, flatpak waits forever on a D-Bus autolaunch.
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY


# Runs one step and carries on after a failure, so a broken mirror cannot abort the rest of the setup.
step() {
    echo "==> $1"
    "$1" || echo "!!! step failed: $1"
}


# Where the packages from outside Fedora that came from the ISO get their updates. RPM Fusion's come with
# its release packages.
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
    if rpm -q akmod-facetimehd >/dev/null 2>&1; then
        cat > /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:mulderje:facetimehd-kmod.repo <<'EOF'
[copr:copr.fedorainfracloud.org:mulderje:facetimehd-kmod]
name=Copr repo for facetimehd-kmod owned by mulderje
baseurl=https://download.copr.fedorainfracloud.org/results/mulderje/facetimehd-kmod/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/mulderje/facetimehd-kmod/pubkey.gpg
repo_gpgcheck=0
enabled=1
EOF
    fi
}



# Nested in the root subvolume, so system snapshots leave out containers, virtual machine images and
# Flatpaks: they are large, change often, and rolling them back fixes nothing. Their packages are installed
# by now and may have made the directories, still empty; those become subvolumes with the same owner and
# mode. One that holds anything, or already is a subvolume, stays.
create_excluded_subvolumes() {
    [ "$(findmnt -no FSTYPE /)" = btrfs ] || return 0
    local path owner mode
    for path in /var/lib/docker /var/lib/libvirt/images /var/lib/flatpak; do
        owner=root:root mode=755
        if [ -e "$path" ]; then
            btrfs subvolume show "$path" >/dev/null 2>&1 && continue
            [ -d "$path" ] && [ -z "$(ls -A "$path")" ] || continue
            owner=$(stat -c %U:%G "$path")
            mode=$(stat -c %a "$path")
            rmdir "$path" || return 1
        fi
        mkdir -p "$(dirname "$path")"
        btrfs subvolume create "$path" && chown "$owner" "$path" && chmod "$mode" "$path" &&
            restorecon -R "$path" || return 1
    done
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
    # Snapshots come only from dnf, before and after each change, and by hand; snapshots on a clock add
    # little, since the system changes through dnf. They use at most 10% of the disk and leave at least
    # 20% free; ranges let the cleanup go down to 2.
    snapper --no-dbus -c root set-config \
        TIMELINE_CREATE=no \
        NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=2-4 \
        SPACE_LIMIT=0.1 FREE_LIMIT=0.2 || return 1
    systemctl enable snapper-cleanup.timer
}

enable_keyring_login() {
    authselect enable-feature with-pam-gnome-keyring && authselect apply-changes
}

enable_services() {
    systemctl enable sddm bluetooth power-profiles-daemon cups docker
    systemctl set-default graphical.target
}

# The splash, its initramfs for every kernel, and the GRUB menu hidden unless Esc is pressed.
configure_boot() {
    /usr/libexec/hyprdora/boot-theme installer
}

configure_users() {
    useradd -D -s /bin/zsh >/dev/null
    local admins user
    admins=$(getent group wheel | cut -d: -f4 | tr ',' ' ')
    for user in $admins; do
        usermod -s /bin/zsh -aG docker "$user"
    done
}

step enable_vendor_repositories
step create_excluded_subvolumes
step install_flatpaks
step configure_snapshots
step enable_keyring_login
step enable_services
step configure_boot
step configure_users
