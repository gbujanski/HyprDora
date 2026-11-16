#!/bin/bash
# Builds the ISO's package repository: HyprDora's own packages, and every package from outside Fedora that
# installing from the kickstart needs, with the drivers for every computer its %pre can pick. The installer
# checks no signatures, so each outside package must carry a valid signature from a key in keys/, or the
# build stops. Fedora's packages stay out: the installer fetches them through metalinks.
#
# Usage: build-repo.sh KICKSTART RPMS_DIR OUT_DIR
# Downloads are kept in build/iso/work between builds, so a rebuild fetches only what changed.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
ks=$1
rpms=$2
out=$3
here_root=$(cd "$here/../.." && pwd)
work=$here_root/build/iso/work
mkdir -p "$work"

# What the kickstart installs: the %packages lines, and every package its %pre may add.
mapfile -t specs < <(sed -n '/^%packages/,/^%end/p' "$ks" | grep -vE '^%|^#|^$')
mapfile -t hardware < <(sed -n 's/.*&& add //p' "$ks" | tr ' ' '\n')
install=() exclude=()
for spec in "${specs[@]}" "${hardware[@]}"; do
    case "$spec" in
        -*) exclude+=("${spec#-}") ;;
        *) install+=("$spec") ;;
    esac
done

# HyprDora's packages as a repository, under the name the kickstart uses.
rm -rf "$work/local" "$work/root" "$out"
mkdir -p "$work/local" "$work/root" "$work/download"
cp "$rpms"/hyprdora*.rpm "$work/local/"
createrepo_c -q "$work/local"

# shellcheck disable=SC2054 # The commas belong to --repofrompath.
dnf=(dnf5 --use-host-config --releasever="$(rpm -E %fedora)" --setopt=reposdir="$here"
    --setopt=cachedir="$work/cache" --repofrompath=hyprdora-local,"$work/local"
    --setopt=hyprdora-local.gpgcheck=0)

# The whole installation resolved in an empty root; an excluded package a group lists is skipped, as the
# installer skips it.
echo "Resolving the installation..."
LC_ALL=C "${dnf[@]}" install --assumeno --skip-unavailable --installroot="$work/root" \
    --exclude="$(IFS=,; echo "${exclude[*]}")" "${install[@]}" >"$work/transaction.log" 2>&1 || true
grep -q '^Transaction Summary' "$work/transaction.log" || {
    cat "$work/transaction.log" >&2
    exit 1
}

# Rows of the transaction: name, arch, epoch:version-release, repository, size.
mapfile -t outside < <(awk 'NF >= 6 && $3 ~ /^[0-9]+:/ && $4 != "fedora" && $4 != "updates" && $4 != "hyprdora-local" {
    print $1 "-" $3 "." $2 }' "$work/transaction.log")
# Only the packages not downloaded yet. Files are named by their repository, so each is matched by the
# name, epoch, version, release and arch inside it; files from earlier builds no longer needed go.
nevra_of() {
    rpm -qp --nosignature --qf '%{NAME}-%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}' "$1" 2>/dev/null
}
mkdir -p "$work/download"
declare -A have=()
for file in "$work"/download/*.rpm; do
    [ -e "$file" ] || continue
    have[$(nevra_of "$file")]=$file
done
missing=()
for nevra in "${outside[@]}"; do
    [ -n "${have[$nevra]:-}" ] || missing+=("$nevra")
done
echo "Packages from outside Fedora: ${#outside[@]}, to download: ${#missing[@]}"
if [ "${#missing[@]}" -gt 0 ]; then
    LC_ALL=C "${dnf[@]}" download --destdir="$work/download" "${missing[@]}" >"$work/download.log" 2>&1 || {
        cat "$work/download.log" >&2
        exit 1
    }
fi
declare -A needed=()
for nevra in "${outside[@]}"; do
    needed[$nevra]=1
done
wanted=()
for file in "$work"/download/*.rpm; do
    nevra=$(nevra_of "$file")
    if [ -n "${needed[$nevra]:-}" ]; then
        wanted+=("$file")
        unset "needed[$nevra]"
    else
        rm -f "$file"
    fi
done
if [ "${#needed[@]}" -gt 0 ]; then
    echo "Not downloaded: ${!needed[*]}" >&2
    exit 1
fi

# Signatures against the pinned keys only, in a database of their own.
db="$work/keys-db"
rm -rf "$db"
mkdir -p "$db"
for key in "$here"/keys/*.asc; do
    rpm --dbpath "$db" --import "$key"
done
bad=0
for file in "${wanted[@]}"; do
    result=$(LC_ALL=C rpm --dbpath "$db" --checksig "$file" 2>&1)
    if [ "${result##*: }" != "digests signatures OK" ]; then
        echo "Bad or missing signature: $result" >&2
        bad=1
    fi
done
[ "$bad" = 0 ] || exit 1

mkdir -p "$out"
cp "$work/local"/*.rpm "${wanted[@]}" "$out/"
createrepo_c -q "$out"
echo "Repository: $(find "$out" -name '*.rpm' | wc -l) packages, $(du -sh "$out" | cut -f1)"
