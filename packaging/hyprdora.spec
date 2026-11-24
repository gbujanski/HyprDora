# The released version, raised for each release together with the tag vX.Y.Z. A local build (make rpm) adds
# a snapshot, such as 0.1.0^20261124.153000.git045dbd0: above this release and below the next, so the next
# release from COPR replaces it.
%global base_version 0.1.0

Name:           hyprdora
Version:        %{base_version}%{?snapshot:^%{snapshot}}
Release:        1%{?dist}
Summary:        Hyprland desktop with a custom Quickshell shell
License:        MIT AND OFL-1.1
URL:            https://github.com/gbujanski/HyprDora
Source0:        %{name}-%{base_version}.tar.gz
BuildArch:      noarch

# Hyprland
Requires:       hyprland
Requires:       hyprpaper
Requires:       hypridle
Requires:       polkit
# Calendar events of online accounts, over CalDAV.
Requires:       python3-icalendar
# Repeating events of the offline calendar.
Requires:       python3-dateutil
Requires:       xdg-desktop-portal-hyprland
Requires:       xdg-desktop-portal-gtk
Requires:       xdg-utils
Requires:       qt5-qtwayland
Requires:       qt6-qtwayland

# Shell
Requires:       quickshell
Requires:       brightnessctl
Requires:       playerctl
Requires:       adwaita-sans-fonts
Requires:       python3-gobject
Requires:       libnotify
Requires:       glib2

# System
Requires:       pipewire
Requires:       pipewire-pulseaudio
Requires:       wireplumber
Requires:       bluez
Requires:       NetworkManager-wifi
Requires:       wpa_supplicant
Requires:       iw
Requires:       NetworkManager-tui
Requires:       NetworkManager-openvpn
Requires:       zenity
Requires:       xdg-terminal-exec
Requires:       power-profiles-daemon
Requires:       gnome-keyring
Requires:       gnome-keyring-pam
Requires:       gvfs
# Removable drives on the bar: UDisks to unmount and power them off, fuser to name what holds a busy one.
Requires:       udisks2
Requires:       psmisc
# Keyboard layout names in the interface's language, from xkeyboard-config's translations.
Requires:       gettext-runtime
# The camera indicator: inotify reports a camera device opened or closed, so nothing polls for it.
Requires:       inotify-tools
Requires:       xdg-user-dirs
Requires:       cups
Requires:       system-config-printer
# Network scanners without drivers (eSCL/AirScan, WSD), and an application to scan.
Requires:       sane-airscan
Requires:       simple-scan
# A place to find and install applications, from RPM repositories and Flathub; updates stay with the shell.
Requires:       gnome-software
# Flathub, for the software centre and the applications chosen on the welcome screen.
Requires:       flatpak

# Desktop tools
Requires:       cliphist
Requires:       wl-clipboard
Requires:       grim
Requires:       swappy
Requires:       wf-recorder
# Tabs and panes in the terminal; Alacritty opens in it.
Requires:       tmux
# The only H.264 encoder without RPM Fusion; it comes from a repository that may be disabled.
Recommends:     openh264

# Applications
Requires:       alacritty
Requires:       btop
Requires:       nautilus
Requires:       nautilus-python
Requires:       gst-thumbnailers
Requires:       gvfs-mtp
Requires:       gvfs-smb
Requires:       loupe
Requires:       showtime
Requires:       papers
Requires:       gnome-calculator
Requires:       gnome-text-editor
Requires:       gnome-disk-utility

# Base tools
Requires:       git
Requires:       curl
Requires:       wget
Requires:       tar
Requires:       unzip
Requires:       p7zip
Requires:       pciutils

# Look and login
Requires:       papirus-icon-theme
Requires:       bibata-cursor-themes
Requires:       sddm
# The boot splash: a script theme that draws text.
Requires:       plymouth-plugin-script
Requires:       plymouth-plugin-label
Requires(post): sddm

# Snapshots
Requires:       snapper
Requires:       libdnf5-plugin-actions
Requires:       btrfs-assistant

# The applications of the old extras package are offered on the welcome screen instead; its Neovim config is here.
Obsoletes:      hyprdora-extras <= %{version}-%{release}

%description
HyprDora is a Hyprland desktop on Fedora with a custom Quickshell shell. This
package holds the shell, default configuration and the programs the desktop
needs. Files in the user's config directory override the packaged defaults.

%package repos
Summary:        Repositories that provide Hyprland and the cursor theme for HyprDora
License:        MIT

%description repos
Enables the COPR repositories that hold Hyprland and the Bibata cursor theme,
so the hyprdora package can be installed on an existing Fedora system.

%package release
# The release follows Fedora's, which dnf reads as $releasever; HyprDora's own version goes in the release
# number, so a new HyprDora version also updates this package.
Version:        %{fedora}
Release:        1.%{base_version}%{?snapshot:.%{snapshot}}%{?dist}
Summary:        HyprDora's name and version, and the defaults a Fedora system starts with
License:        MIT
Provides:       system-release
Provides:       system-release(%{fedora})
Requires:       fedora-repos(%{fedora})
Conflicts:      fedora-release
Conflicts:      fedora-release-common
Conflicts:      fedora-release-identity
Conflicts:      generic-release
Conflicts:      generic-release-common

%description release
Names the system HyprDora in os-release, in place of fedora-release, as
Fedora asks of remixes that add software from outside Fedora. Its ID is
hyprdora, with ID_LIKE=fedora. Everything else comes from Fedora and is
kept as it is there: the systemd presets that enable the services a Fedora
system expects, dnf's defaults, the console greeting and the RPM macros,
%fedora and %dist among them, which drivers built on this computer use.
dnf copr is told to pick Fedora's builds.

%package logos
Summary:        HyprDora's logo where the system looks for its distribution's
License:        MIT
Provides:       system-logos
Conflicts:      fedora-logos
Conflicts:      generic-logos

%description logos
HyprDora's logo in place of fedora-logos, for programs that show the
distribution's logo, such as the login screen.

%prep
%autosetup -n %{name}-%{base_version}

%build

%install
install -d %{buildroot}%{_datadir}/%{name}/assets
cp -a shell hypr configs %{buildroot}%{_datadir}/%{name}/
install -pm 644 assets/*.jpg %{buildroot}%{_datadir}/%{name}/assets/

# The logo as an icon named hyprdora, drawn by packaging/logo/make-logo.py.
for size in 16 22 24 32 48 64 128 256 512; do
    install -Dpm 644 assets/logo/icons/hyprdora-$size.png \
        %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/hyprdora.png
done
install -Dpm 644 assets/logo/hyprdora-mark.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/hyprdora.svg

install -d %{buildroot}%{_datadir}/fonts/%{name}
install -pm 644 assets/fonts/*.ttf %{buildroot}%{_datadir}/fonts/%{name}/

install -d %{buildroot}%{_sysconfdir}/xdg/quickshell
ln -s ../../..%{_datadir}/%{name}/shell %{buildroot}%{_sysconfdir}/xdg/quickshell/%{name}

install -Dpm 644 configs/alacritty/alacritty.toml %{buildroot}%{_sysconfdir}/alacritty/alacritty.toml
install -Dpm 644 configs/sddm/hyprdora.conf %{buildroot}%{_sysconfdir}/sddm.conf.d/hyprdora.conf
install -Dpm 644 configs/session/hyprdora.desktop %{buildroot}%{_datadir}/wayland-sessions/hyprdora.desktop
install -Dpm 644 configs/gtk/90_hyprdora.gschema.override %{buildroot}%{_datadir}/glib-2.0/schemas/90_hyprdora.gschema.override
install -Dpm 644 configs/dnf/hyprdora-snapper.actions %{buildroot}%{_sysconfdir}/dnf/libdnf5-plugins/actions.d/hyprdora-snapper.actions
install -Dpm 755 configs/portal/hyprdora-portal.py %{buildroot}%{_libexecdir}/%{name}/hyprdora-portal
install -Dpm 644 configs/portal/hyprdora.portal %{buildroot}%{_datadir}/xdg-desktop-portal/portals/hyprdora.portal
install -Dpm 644 configs/portal/org.freedesktop.impl.portal.desktop.hyprdora.service %{buildroot}%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprdora.service
install -Dpm 644 configs/portal/hyprland-portals.conf %{buildroot}%{_sysconfdir}/xdg/xdg-desktop-portal/hyprland-portals.conf
install -Dpm 644 configs/nautilus/hyprdora.py %{buildroot}%{_datadir}/nautilus-python/extensions/hyprdora.py
install -Dpm 644 configs/mimeapps.list %{buildroot}%{_sysconfdir}/xdg/mimeapps.list
install -Dpm 644 configs/xdg-terminals.list %{buildroot}%{_sysconfdir}/xdg/xdg-terminals.list
install -Dpm 755 kickstart/system-setup.sh %{buildroot}%{_libexecdir}/%{name}/system-setup.sh
install -Dpm 755 kickstart/first-login.sh %{buildroot}%{_libexecdir}/%{name}/first-login.sh
install -Dpm 755 configs/update/offline-update.sh %{buildroot}%{_libexecdir}/%{name}/offline-update
install -Dpm 755 configs/systemd/shell-stopped.sh %{buildroot}%{_libexecdir}/%{name}/shell-stopped
install -Dpm 755 configs/systemd/shell-start.sh %{buildroot}%{_libexecdir}/%{name}/shell-start
install -Dpm 755 configs/mime/editor-types.sh %{buildroot}%{_libexecdir}/%{name}/editor-types
touch %{buildroot}%{_sysconfdir}/xdg/hyprland-mimeapps.list
install -Dpm 755 configs/tmux/terminal-session.sh %{buildroot}%{_libexecdir}/%{name}/terminal-session
install -Dpm 644 configs/tmux/tmux.conf %{buildroot}%{_sysconfdir}/tmux.conf
install -Dpm 644 configs/nvim/sysinit.vim %{buildroot}%{_sysconfdir}/xdg/nvim/sysinit.vim
install -Dpm 755 configs/update/not-metered.sh %{buildroot}%{_libexecdir}/%{name}/not-metered
install -Dpm 755 configs/plymouth/boot-theme.sh %{buildroot}%{_libexecdir}/%{name}/boot-theme
install -Dpm 644 configs/dracut/90-hyprdora.conf %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/90-hyprdora.conf
install -Dpm 644 configs/plymouth/hyprdora/hyprdora.plymouth %{buildroot}%{_datadir}/plymouth/themes/hyprdora/hyprdora.plymouth
install -Dpm 644 configs/plymouth/hyprdora/hyprdora.script %{buildroot}%{_datadir}/plymouth/themes/hyprdora/hyprdora.script
install -Dpm 644 configs/pam/hyprdora-lock %{buildroot}%{_sysconfdir}/pam.d/hyprdora-lock
install -Dpm 644 configs/update/org.hyprdora.offline-update.policy %{buildroot}%{_datadir}/polkit-1/actions/org.hyprdora.offline-update.policy
install -Dpm 755 configs/restore/system-restore.sh %{buildroot}%{_libexecdir}/%{name}/system-restore
install -Dpm 755 configs/calendar/hyprdora-calendar.py %{buildroot}%{_libexecdir}/%{name}/calendar
install -d %{buildroot}%{_libexecdir}/%{name}/hyprdora_calendar
install -pm 644 configs/calendar/hyprdora_calendar/*.py %{buildroot}%{_libexecdir}/%{name}/hyprdora_calendar/
install -Dpm 755 configs/extras/install-extras.py %{buildroot}%{_libexecdir}/%{name}/install-extras
install -Dpm 644 configs/extras/org.hyprdora.install-extras.policy %{buildroot}%{_datadir}/polkit-1/actions/org.hyprdora.install-extras.policy
install -d %{buildroot}%{_datadir}/%{name}/keys
install -pm 644 packaging/keys/*.asc %{buildroot}%{_datadir}/%{name}/keys/
install -Dpm 644 configs/restore/org.hyprdora.system-restore.policy %{buildroot}%{_datadir}/polkit-1/actions/org.hyprdora.system-restore.policy
install -Dpm 644 configs/polkit/10-hyprdora-software.rules %{buildroot}%{_datadir}/polkit-1/rules.d/10-hyprdora-software.rules
install -Dpm 755 bin/hyprdora %{buildroot}%{_bindir}/hyprdora
install -Dpm 644 configs/dnf/protected.d/hyprdora.conf %{buildroot}%{_sysconfdir}/dnf/protected.d/hyprdora.conf
install -Dpm 644 configs/systemd/hyprdora-hint.service %{buildroot}%{_prefix}/lib/systemd/system/hyprdora-hint.service
install -Dpm 644 configs/systemd/dnf5-makecache.service.d/hyprdora-metered.conf %{buildroot}%{_prefix}/lib/systemd/system/dnf5-makecache.service.d/hyprdora-metered.conf
install -Dpm 644 configs/systemd/plymouth-quit.service.d/hyprdora-retain.conf %{buildroot}%{_prefix}/lib/systemd/system/plymouth-quit.service.d/hyprdora-retain.conf
install -Dpm 644 configs/systemd/akmods.service.d/hyprdora-splash.conf %{buildroot}%{_prefix}/lib/systemd/system/akmods.service.d/hyprdora-splash.conf
install -Dpm 644 configs/logind/50-hyprdora.conf %{buildroot}%{_prefix}/lib/systemd/logind.conf.d/50-hyprdora.conf
install -Dpm 644 configs/sysctl/60-hyprdora-ptrace.conf %{buildroot}%{_prefix}/lib/sysctl.d/60-hyprdora-ptrace.conf
install -Dpm 644 configs/systemd/hyprdora-shell.service %{buildroot}%{_prefix}/lib/systemd/user/hyprdora-shell.service
install -Dpm 644 configs/systemd/hyprdora-session.target %{buildroot}%{_prefix}/lib/systemd/user/hyprdora-session.target
install -d %{buildroot}%{_datadir}/sddm/themes
cp -a configs/sddm/theme/Hyprdora %{buildroot}%{_datadir}/sddm/themes/

install -Dpm 644 packaging/hyprdora-copr.repo %{buildroot}%{_sysconfdir}/yum.repos.d/hyprdora-copr.repo

# hyprdora-release: os-release and the release files, named after HyprDora; the rest as Fedora has it.
install -d %{buildroot}%{_prefix}/lib %{buildroot}%{_sysconfdir}/issue.d
sed 's/@RELEASE@/%{fedora}/g' packaging/release/os-release.in >%{buildroot}%{_prefix}/lib/os-release
echo "HyprDora release %{fedora}" >%{buildroot}%{_prefix}/lib/hyprdora-release
echo "cpe:/o:hyprdora:hyprdora:%{fedora}" >%{buildroot}%{_prefix}/lib/system-release-cpe
install -pm 644 packaging/release/issue packaging/release/issue.net %{buildroot}%{_prefix}/lib/
ln -s ../usr/lib/os-release %{buildroot}%{_sysconfdir}/os-release
ln -s ../usr/lib/hyprdora-release %{buildroot}%{_sysconfdir}/hyprdora-release
# Scripts written for Fedora look for these.
ln -s hyprdora-release %{buildroot}%{_sysconfdir}/fedora-release
ln -s hyprdora-release %{buildroot}%{_sysconfdir}/redhat-release
ln -s hyprdora-release %{buildroot}%{_sysconfdir}/system-release
ln -s ../usr/lib/system-release-cpe %{buildroot}%{_sysconfdir}/system-release-cpe
ln -s ../usr/lib/issue %{buildroot}%{_sysconfdir}/issue
ln -s ../usr/lib/issue.net %{buildroot}%{_sysconfdir}/issue.net
install -Dpm 644 -t %{buildroot}%{_prefix}/lib/systemd/system-preset packaging/release/system-preset/*.preset
install -Dpm 644 -t %{buildroot}%{_prefix}/lib/systemd/user-preset packaging/release/user-preset/*.preset
install -Dpm 644 packaging/release/20-hyprdora-defaults.conf %{buildroot}%{_datadir}/dnf5/libdnf.conf.d/20-hyprdora-defaults.conf
install -Dpm 644 packaging/release/copr.vendor.conf %{buildroot}%{_datadir}/dnf/plugins/copr.vendor.conf
sed 's/@RELEASE@/%{fedora}/g' packaging/release/macros.dist.in >macros.dist
install -Dpm 644 macros.dist %{buildroot}%{_rpmmacrodir}/macros.dist
cp -p packaging/release/LICENSE.fedora-release LICENSE.fedora-release

# hyprdora-logos
install -Dpm 644 assets/logo/system/system-logo-white.png %{buildroot}%{_datadir}/pixmaps/system-logo-white.png

%post
# The login theme uses the last session, so the first login needs one to be set.
if [ ! -e %{_localstatedir}/lib/sddm/state.conf ]; then
    install -d -o sddm -g sddm %{_localstatedir}/lib/sddm
    printf '[Last]\nSession=hyprdora.desktop\n' > %{_localstatedir}/lib/sddm/state.conf
    chown sddm:sddm %{_localstatedir}/lib/sddm/state.conf
fi
# RPM gives every file the same build date, and the greeter's compiled QML cache is checked by file date,
# so it would keep showing the previous login theme. The cache is rebuilt on the next start.
rm -rf %{_localstatedir}/lib/sddm/.cache/sddm-greeter* 2>/dev/null || :
# The ptrace limit applies at once, not only from the next boot.
%sysctl_apply 60-hyprdora-ptrace.conf
# The console reminder of hyprdora --help is written at every boot, in the system language.
systemctl enable hyprdora-hint.service >/dev/null 2>&1 || :
if [ -d /run/systemd/system ]; then
    systemctl start hyprdora-hint.service >/dev/null 2>&1 || :
fi

%posttrans
# The boot splash and the hidden GRUB menu; also rebuilds the initramfs when the splash changed.
%{_libexecdir}/%{name}/boot-theme >/dev/null 2>&1 || :
# Every text file type opens in the text editor.
%{_libexecdir}/%{name}/editor-types >/dev/null 2>&1 || :

# The text types follow the MIME database, after Fedora's own trigger has rebuilt it (priority 1000000).
%transfiletriggerin -P 999000 -- %{_datadir}/mime
%{_libexecdir}/%{name}/editor-types >/dev/null 2>&1 || :

%transfiletriggerpostun -P 999000 -- %{_datadir}/mime
%{_libexecdir}/%{name}/editor-types >/dev/null 2>&1 || :

%preun
if [ "$1" -eq 0 ]; then
    systemctl disable hyprdora-hint.service >/dev/null 2>&1 || :
fi

%postun
if [ "$1" -eq 0 ]; then
    # Back to Fedora's splash; the next initramfs build picks it up.
    plymouth-set-default-theme --reset >/dev/null 2>&1 || :
fi

%files
%dir %{_datadir}/plymouth/themes/hyprdora
%{_datadir}/plymouth/themes/hyprdora/hyprdora.plymouth
# The version is written into it when the package installs.
%verify(not md5 size mtime) %{_datadir}/plymouth/themes/hyprdora/hyprdora.script
%license LICENSE THIRD-PARTY.md assets/fonts/OFL.txt
%doc README.md
%{_datadir}/%{name}
%{_libexecdir}/%{name}
%{_datadir}/icons/hicolor/*/apps/hyprdora.*
%{_datadir}/nautilus-python/extensions/hyprdora.py
%{_datadir}/xdg-desktop-portal/portals/hyprdora.portal
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprdora.service
%dir %{_sysconfdir}/xdg/xdg-desktop-portal
%config(noreplace) %{_sysconfdir}/xdg/xdg-desktop-portal/hyprland-portals.conf
%config(noreplace) %{_sysconfdir}/xdg/mimeapps.list
# Written by editor-types.
%ghost %{_sysconfdir}/xdg/hyprland-mimeapps.list
%config(noreplace) %{_sysconfdir}/xdg/xdg-terminals.list
%config(noreplace) %{_sysconfdir}/dnf/libdnf5-plugins/actions.d/hyprdora-snapper.actions
%{_datadir}/fonts/%{name}
%{_datadir}/wayland-sessions/hyprdora.desktop
%{_prefix}/lib/systemd/user/hyprdora-session.target
%{_prefix}/lib/systemd/user/hyprdora-shell.service
%{_prefix}/lib/systemd/logind.conf.d/50-hyprdora.conf
%{_prefix}/lib/sysctl.d/60-hyprdora-ptrace.conf
%{_bindir}/hyprdora
%{_prefix}/lib/systemd/system/hyprdora-hint.service
%{_prefix}/lib/systemd/system/dnf5-makecache.service.d/hyprdora-metered.conf
%{_prefix}/lib/systemd/system/plymouth-quit.service.d/hyprdora-retain.conf
%{_prefix}/lib/systemd/system/akmods.service.d/hyprdora-splash.conf
%{_prefix}/lib/dracut/dracut.conf.d/90-hyprdora.conf
%config(noreplace) %{_sysconfdir}/dnf/protected.d/hyprdora.conf
%config(noreplace) %{_sysconfdir}/pam.d/hyprdora-lock
%{_datadir}/glib-2.0/schemas/90_hyprdora.gschema.override
%{_datadir}/polkit-1/actions/org.hyprdora.offline-update.policy
%{_datadir}/polkit-1/actions/org.hyprdora.system-restore.policy
%{_datadir}/polkit-1/actions/org.hyprdora.install-extras.policy
%{_datadir}/polkit-1/rules.d/10-hyprdora-software.rules
%{_datadir}/sddm/themes/Hyprdora
%dir %{_sysconfdir}/xdg/quickshell
%{_sysconfdir}/xdg/quickshell/%{name}
%dir %{_sysconfdir}/alacritty
%config(noreplace) %{_sysconfdir}/alacritty/alacritty.toml
%config(noreplace) %{_sysconfdir}/tmux.conf
%config(noreplace) %{_sysconfdir}/sddm.conf.d/hyprdora.conf
%config(noreplace) %{_sysconfdir}/xdg/nvim/sysinit.vim

%files repos
%config(noreplace) %{_sysconfdir}/yum.repos.d/hyprdora-copr.repo

%files release
%license LICENSE.fedora-release
%{_prefix}/lib/os-release
%{_prefix}/lib/hyprdora-release
%{_prefix}/lib/system-release-cpe
%{_prefix}/lib/issue
%{_prefix}/lib/issue.net
%{_sysconfdir}/os-release
%{_sysconfdir}/hyprdora-release
%{_sysconfdir}/fedora-release
%{_sysconfdir}/redhat-release
%{_sysconfdir}/system-release
%{_sysconfdir}/system-release-cpe
%config(noreplace) %{_sysconfdir}/issue
%config(noreplace) %{_sysconfdir}/issue.net
%dir %{_sysconfdir}/issue.d
%{_prefix}/lib/systemd/system-preset/*.preset
%{_prefix}/lib/systemd/user-preset/*.preset
%{_datadir}/dnf5/libdnf.conf.d/20-hyprdora-defaults.conf
%dir %{_datadir}/dnf
%dir %{_datadir}/dnf/plugins
%{_datadir}/dnf/plugins/copr.vendor.conf
%{_rpmmacrodir}/macros.dist

%files logos
%{_datadir}/pixmaps/system-logo-white.png

%changelog
* Mon Nov 09 2026 Grzegorz Bujański <grzegorz.bujanski@gmail.com> - 0.1.0-1
- First package
