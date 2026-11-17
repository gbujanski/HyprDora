#!/bin/bash
# Sets up a quiet, themed boot: HyprDora's splash with the installed version in its first line, the splash
# only on the real graphics driver, and the GRUB menu hidden unless Esc is pressed while it loads.
#
# Usage: boot-theme [package|installer]
#   package    after the package installs or updates, on the running system: rebuilds the running kernel's
#              initramfs when the splash changed. Inside the installer's chroot it changes only files, as
#              the installer step below does the rest.
#   installer  from the kickstart, after the bootloader is in place: also rebuilds every kernel's initramfs.
#
# Plymouth starts on the firmware's framebuffer by default, which the graphics driver takes over with its
# contents; that early frame then reappeared after the splash ended and between sessions. Waiting for the
# real driver leaves it black for a moment instead. The kernel's console likewise keeps the firmware's
# picture, the Apple logo, until it prints something, and it showed while a session started; with
# fbcon=nodefer the console clears the screen as soon as the driver loads, with no cursor blinking on it.
set -u

mode=${1:-package}
dir=/usr/share/plymouth/themes/hyprdora
conf=/etc/plymouth/plymouthd.conf
state=/var/lib/hyprdora
running=0
[ -d /run/systemd/system ] && running=1

version=$(rpm -q --qf '%{VERSION}' hyprdora 2>/dev/null) || version=""
case "$version" in
    *[!0-9.]* | "") version=0 ;;
esac
sed -i "s/^version = .*/version = \"$version\";/" "$dir/hyprdora.script"

plymouth-set-default-theme hyprdora || exit 1
# Last in the file: plymouth-set-default-theme, which dracut asks for the theme, reads only the first key of
# the section and would take the theme for missing.
sed -i '/^UseSimpledrm=/d' "$conf"
echo 'UseSimpledrm=0' >>"$conf"

# The menu shows only when Esc is pressed within a second; done once, so a later choice of your own stays.
hide_grub_menu() {
    [ -e "$state/grub-menu-hidden" ] || [ ! -f /etc/default/grub ] && return 0
    sed -i '/^GRUB_TIMEOUT=/d; /^GRUB_TIMEOUT_STYLE=/d' /etc/default/grub
    printf 'GRUB_TIMEOUT=1\nGRUB_TIMEOUT_STYLE=hidden\n' >>/etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || return 1
    install -d -m 755 "$state"
    touch "$state/grub-menu-hidden"
}

# Done once, like the menu, for the installed kernels and through the GRUB defaults for later ones.
quiet_console() {
    local args="fbcon=nodefer vt.global_cursor_default=0"
    [ -e "$state/console-cleared" ] || [ ! -f /etc/default/grub ] && return 0
    grubby --update-kernel=ALL --args="$args" || return 1
    grep -q 'fbcon=nodefer' /etc/default/grub ||
        sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $args\"/" /etc/default/grub
    install -d -m 755 "$state"
    touch "$state/console-cleared"
}

# The initramfs holds the splash shown before the disk is mounted, its settings, and what HyprDora's dracut
# settings leave out.
rebuild_initramfs() {
    local sum
    sum=$(cat "$dir"/* "$conf" /usr/lib/dracut/dracut.conf.d/90-hyprdora.conf 2>/dev/null | sha256sum | cut -d' ' -f1)
    [ "$(cat "$state/boot-theme.sum" 2>/dev/null)" = "$sum" ] && return 0
    if [ "$mode" = installer ]; then
        dracut -f --regenerate-all || return 1
    else
        local kernel
        kernel=$(uname -r)
        [ -d "/lib/modules/$kernel" ] || return 0
        dracut -f --kver "$kernel" || return 1
    fi
    install -d -m 755 "$state"
    echo "$sum" >"$state/boot-theme.sum"
}

if [ "$mode" = installer ] || [ "$running" = 1 ]; then
    hide_grub_menu
    quiet_console
    rebuild_initramfs
fi
