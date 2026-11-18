#!/bin/bash
# Builds the installer's product.img, which Anaconda unpacks over its own files when it starts: a build
# stamp that names the product HyprDora, an Anaconda profile, and HyprDora's logo and colours in place of
# Fedora's. The rest of the installer is Fedora's.
#
# Usage: make-product.sh OUT_IMG
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
top=$(cd "$here/../.." && pwd)
out=$1
release=$(rpm -E %fedora)
tree=$(mktemp -d)
trap 'rm -rf "$tree"' EXIT

cat >"$tree/.buildstamp" <<STAMP
[Main]
Product=HyprDora
Version=$release
BugURL=https://github.com/gbujanski/HyprDora/issues
IsFinal=True
UUID=$(date -u +%Y%m%d%H%M).x86_64
STAMP
install -Dpm 644 "$here/product/hyprdora.conf" "$tree/etc/anaconda/profile.d/hyprdora.conf"
pixmaps=$tree/usr/share/anaconda/pixmaps
install -Dpm 644 "$here/product/hyprdora.css" "$pixmaps/hyprdora.css"
install -pm 644 "$top/assets/logo/system/anaconda-sidebar-logo.png" "$pixmaps/sidebar-logo.png"
install -pm 644 "$top/assets/logo/system/anaconda-header.png" "$pixmaps/anaconda_header.png"

mkdir -p "$(dirname "$out")"
(cd "$tree" && find . | LC_ALL=C sort | cpio --quiet -o -H newc -R 0:0) | gzip -9 >"$out"
