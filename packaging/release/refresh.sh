#!/bin/bash
# Refreshes what hyprdora-release takes from Fedora: the systemd presets, which enable the services a
# Fedora system expects (sound, DNS, the login screen), dnf5's defaults, which turn on signature checks,
# the console greeting, the licence they come under, and the date Fedora's support ends. They carry no
# branding. It also shows how Fedora's RPM macros differ from ours, which keep all but Fedora's name. Run it
# for each new Fedora release before building, and review the diff.
#
# Usage: refresh.sh [RELEASE]   (default: this system's release)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
release=${1:-$(rpm -E %fedora)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

dnf5 -q download --releasever="$release" --destdir="$work" fedora-release-common fedora-release-identity-basic
mkdir "$work/root"
for package in "$work"/*.rpm; do
    (cd "$work/root" && rpm2cpio "$package" | cpio -idm --quiet)
done
root=$work/root

cp "$root"/usr/lib/systemd/system-preset/*.preset "$here/system-preset/"
cp "$root"/usr/lib/systemd/user-preset/*.preset "$here/user-preset/"
cp "$root/usr/share/dnf5/libdnf.conf.d/20-fedora-defaults.conf" "$here/20-hyprdora-defaults.conf"
cp "$root/usr/lib/issue" "$here/issue"
cp "$root/usr/lib/issue.net" "$here/issue.net"
cp "$root/usr/share/licenses/fedora-release-common/LICENSE" "$here/LICENSE.fedora-release"
end=$(sed -n 's/^SUPPORT_END=//p' "$root/usr/lib/os-release")
sed -i "s/^SUPPORT_END=.*/SUPPORT_END=$end/" "$here/os-release.in"

echo "Fedora's RPM macros against ours (only the name, vendor and addresses should differ):"
diff "$root/usr/lib/rpm/macros.d/macros.dist" <(sed "s/@RELEASE@/$release/g" "$here/macros.dist.in") || true
echo "Refreshed from fedora-release-common for Fedora $release; review with git diff."
