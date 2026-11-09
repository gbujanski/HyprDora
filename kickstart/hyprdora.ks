# HyprDora install description.
# It sets no disk layout and no user account, so the installer stops and asks for them.

graphical

url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch"
repo --name=hyprdora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f$releasever&arch=$basearch"
repo --name=hyprdora-hyprland --baseurl="https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/fedora-$releasever-$basearch/"
repo --name=hyprdora-rendezvous --baseurl="https://download.copr.fedorainfracloud.org/results/peterwu/rendezvous/fedora-$releasever-$basearch/"
repo --name=hyprdora-local --baseurl=file:///run/install/repo/hyprdora

%packages
@core
@hardware-support
hyprdora
hyprdora-repos
%end

%post --nochroot
cp /run/install/repo/hyprdora/hyprdora-extras-*.rpm /mnt/sysroot/var/tmp/
%end

%post --log=/root/hyprdora-setup.log
/usr/libexec/hyprdora/system-setup.sh /var/tmp/hyprdora-extras-*.rpm
%end
