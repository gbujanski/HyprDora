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


# Where the camera driver from the ISO gets its updates, on MacBooks that have the camera. RPM Fusion's
# repositories come with its release packages; applications from other makers add theirs when chosen on the
# welcome screen.
enable_hardware_repositories() {
    rpm -q akmod-facetimehd >/dev/null 2>&1 || return 0
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


# Flathub, for the software centre and the applications chosen on the welcome screen.
add_flathub() {
    flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
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

# Ten wrong passwords in a row lock the account for five minutes, at the lock screen, sudo and polkit alike,
# so a password cannot be guessed at length; the lock screen shows why it refuses. Fedora sets no limit.
limit_password_attempts() {
    sed -i -e 's/^#\? *deny *=.*/deny = 10/' -e 's/^#\? *unlock_time *=.*/unlock_time = 300/' /etc/security/faillock.conf &&
        authselect enable-feature with-faillock && authselect apply-changes
}

enable_services() {
    systemctl enable sddm bluetooth power-profiles-daemon cups
    systemctl set-default graphical.target
}

# The splash, its initramfs for every kernel, and the GRUB menu hidden unless Esc is pressed.
configure_boot() {
    /usr/libexec/hyprdora/boot-theme installer
}

step enable_hardware_repositories
step create_excluded_subvolumes
step add_flathub
step configure_snapshots
step enable_keyring_login
step limit_password_attempts
step enable_services
step configure_boot
