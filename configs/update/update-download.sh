#!/bin/bash
# Downloads the available updates in the background, so that updating at power off or restart only installs
# them. Run as root by hyprdora-update-download.service after each refresh of the package cache, on AC power
# and off metered networks. Packages go to dnf's cache, which `dnf5 upgrade --offline` takes them from.
# Flatpaks are pulled without being deployed; their commits are listed in $pulled, so the shell does not
# count them as still to download.
set -u
export LC_ALL=C

pulled=/var/lib/hyprdora/flatpak-pulled
# 5 GB, in the kilobytes df reports.
min_free=5000000

# dnf leaves packages downloaded ahead in its cache after installing them, at restart or from a terminal;
# one whose exact version is installed is not needed any more. A package downloaded a month ago has most
# likely been replaced by a newer update; one still needed comes down again.
find /var/cache/libdnf5 -path '*/packages/*.rpm' -mtime +30 -delete
for package in /var/cache/libdnf5/*/packages/*.rpm; do
    [ -e "$package" ] || continue
    name=${package##*/}
    rpm -q --quiet "${name%.rpm}" && rm -f "$package"
done

free=$(df --output=avail -k /var/cache | tail -n 1)
if [ "${free// /}" -lt "$min_free" ]; then
    echo "less than 5 GB free in /var/cache; nothing downloaded"
    exit 0
fi

status=0
dnf5 upgrade --downloadonly --assumeyes --quiet || status=1

if command -v flatpak >/dev/null; then
    # Read before pulling, so the list holds the commits being pulled.
    commits=$(flatpak remote-ls --system --updates --columns=commit)
    if flatpak update --system --assumeyes --noninteractive --no-deploy >/dev/null; then
        install -d -m 755 /var/lib/hyprdora
        printf '%s\n' "$commits" >"$pulled.new"
        chmod 644 "$pulled.new"
        mv -f "$pulled.new" "$pulled"
    else
        status=1
    fi
fi
exit "$status"
