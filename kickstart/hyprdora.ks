# HyprDora install description.
# It sets no disk layout and no user account, so the installer stops and asks for them.
#
# The installer checks no package signatures. Fedora's packages come through metalinks, which carry
# checksums of the repository metadata; every other package is in the ISO's own repository, put there by
# packaging/iso/build-repo.sh only after its signature was checked against a pinned key. The package list
# below is also what that script resolves, so both stay the same.

graphical

url --metalink="https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=$basearch"
repo --name=hyprdora-updates --metalink="https://mirrors.fedoraproject.org/metalink?repo=updates-released-f$releasever&arch=$basearch"
repo --name=hyprdora-local --baseurl=file:///run/install/repo/hyprdora

# Drivers for this computer, from the PCI devices in sysfs: class, vendor and device.
%pre --interpreter=/usr/bin/bash
out=/tmp/hyprdora-hardware.ks
: >"$out"
add() { printf '%s\n' "$@" >>"$out"; }
pci() {
    local d
    for d in /sys/bus/pci/devices/*; do
        [[ $(<"$d/class") == "$1"* ]] && [ "$(<"$d/vendor")" = "$2" ] || continue
        [ -z "${3:-}" ] || [ "$(<"$d/device")" = "$3" ] || continue
        return 0
    done
    return 1
}
pci 0x03 0x8086 && add intel-media-driver
pci 0x03 0x1002 && add mesa-va-drivers-freeworld -mesa-va-drivers
pci 0x0280 0x14e4 && add broadcom-wl akmod-wl kernel-devel
# The FaceTime HD camera in MacBooks from 2013 to 2017.
pci 0x0480 0x14e4 0x1570 && add akmod-facetimehd facetimehd-firmware kernel-devel
true
%end

%packages
@core
@hardware-support
@multimedia
hyprdora
hyprdora-repos
hyprdora-extras
rpmfusion-free-release
rpmfusion-nonfree-release
ffmpeg
gstreamer1-plugins-bad-freeworld
gstreamer1-plugins-ugly
-ffmpeg-free
-PackageKit-gstreamer-plugin
-libheif-freeworld
%include /tmp/hyprdora-hardware.ks
%end

%post --log=/root/hyprdora-setup.log
/usr/libexec/hyprdora/system-setup.sh
%end
