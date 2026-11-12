Name:           hyprdora
Version:        0.1.0
Release:        1%{?dist}
Summary:        Hyprland desktop with a custom Quickshell shell
License:        MIT AND OFL-1.1
URL:            https://github.com/gbujanski/HyprDora
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

# Hyprland
Requires:       hyprland
Requires:       hyprpaper
Requires:       hypridle
Requires:       hyprpolkitagent
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
Requires:       xdg-user-dirs
Requires:       cups
Requires:       system-config-printer

# Desktop tools
Requires:       cliphist
Requires:       wl-clipboard
Requires:       grim
Requires:       swappy
Requires:       wf-recorder
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
Requires(post): sddm

# Snapshots
Requires:       snapper
Requires:       libdnf5-plugin-actions
Requires:       btrfs-assistant

%description
HyprDora is a Hyprland desktop on Fedora with a custom Quickshell shell. This
package holds the shell, default configuration and the programs the desktop
needs. Files in the user's config directory override the packaged defaults.

%package repos
Summary:        Repositories that provide Hyprland and the cursor theme for HyprDora

%description repos
Enables the COPR repositories that hold Hyprland and the Bibata cursor theme,
so the hyprdora package can be installed on an existing Fedora system.

%package extras
Summary:        Personal applications and development tools for HyprDora
Requires:       neovim
Requires:       code
Requires:       discord
Requires:       filezilla
Requires:       gimp
Requires:       onlyoffice-desktopeditors
Requires:       virt-manager
Requires:       docker-ce
Requires:       docker-ce-cli
Requires:       containerd.io
Requires:       docker-buildx-plugin
Requires:       docker-compose-plugin
Requires:       python3
Requires:       nodejs
Requires:       java-25-openjdk
Requires:       dotnet-sdk-10.0
Requires:       zsh
Requires:       flatpak
Requires:       mediawriter

%description extras
Applications kept separate from the desktop. The kickstart enables the
repositories they come from.

%prep
%autosetup

%build

%install
install -d %{buildroot}%{_datadir}/%{name}/assets
cp -a shell hypr configs %{buildroot}%{_datadir}/%{name}/
install -pm 644 assets/*.jpg %{buildroot}%{_datadir}/%{name}/assets/

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
install -Dpm 644 configs/pam/hyprdora-lock %{buildroot}%{_sysconfdir}/pam.d/hyprdora-lock
install -Dpm 644 configs/update/org.hyprdora.offline-update.policy %{buildroot}%{_datadir}/polkit-1/actions/org.hyprdora.offline-update.policy
install -Dpm 755 bin/hyprdora %{buildroot}%{_bindir}/hyprdora
install -Dpm 644 configs/dnf/protected.d/hyprdora.conf %{buildroot}%{_sysconfdir}/dnf/protected.d/hyprdora.conf
install -Dpm 644 configs/systemd/hyprdora-hint.service %{buildroot}%{_prefix}/lib/systemd/system/hyprdora-hint.service
install -Dpm 644 configs/logind/50-hyprdora.conf %{buildroot}%{_prefix}/lib/systemd/logind.conf.d/50-hyprdora.conf
install -Dpm 644 configs/systemd/hyprdora-shell.service %{buildroot}%{_prefix}/lib/systemd/user/hyprdora-shell.service
install -Dpm 644 configs/systemd/hyprdora-session.target %{buildroot}%{_prefix}/lib/systemd/user/hyprdora-session.target
install -d %{buildroot}%{_datadir}/sddm/themes
cp -a configs/sddm/theme/Hyprdora %{buildroot}%{_datadir}/sddm/themes/

install -Dpm 644 packaging/hyprdora-copr.repo %{buildroot}%{_sysconfdir}/yum.repos.d/hyprdora-copr.repo

%post
# The login theme uses the last session, so the first login needs one to be set.
if [ ! -e %{_localstatedir}/lib/sddm/state.conf ]; then
    install -d -o sddm -g sddm %{_localstatedir}/lib/sddm
    printf '[Last]\nSession=hyprdora.desktop\n' > %{_localstatedir}/lib/sddm/state.conf
    chown sddm:sddm %{_localstatedir}/lib/sddm/state.conf
fi
# The console reminder of hyprdora --help is written at every boot, in the system language.
systemctl enable hyprdora-hint.service >/dev/null 2>&1 || :
if [ -d /run/systemd/system ]; then
    systemctl start hyprdora-hint.service >/dev/null 2>&1 || :
fi

%preun
if [ "$1" -eq 0 ]; then
    systemctl disable hyprdora-hint.service >/dev/null 2>&1 || :
fi

%files
%license LICENSE assets/fonts/OFL.txt
%doc README.md
%{_datadir}/%{name}
%{_libexecdir}/%{name}
%{_datadir}/nautilus-python/extensions/hyprdora.py
%{_datadir}/xdg-desktop-portal/portals/hyprdora.portal
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprdora.service
%dir %{_sysconfdir}/xdg/xdg-desktop-portal
%config(noreplace) %{_sysconfdir}/xdg/xdg-desktop-portal/hyprland-portals.conf
%config(noreplace) %{_sysconfdir}/xdg/mimeapps.list
%config(noreplace) %{_sysconfdir}/xdg/xdg-terminals.list
%config(noreplace) %{_sysconfdir}/dnf/libdnf5-plugins/actions.d/hyprdora-snapper.actions
%{_datadir}/fonts/%{name}
%{_datadir}/wayland-sessions/hyprdora.desktop
%{_prefix}/lib/systemd/user/hyprdora-session.target
%{_prefix}/lib/systemd/user/hyprdora-shell.service
%{_prefix}/lib/systemd/logind.conf.d/50-hyprdora.conf
%{_bindir}/hyprdora
%{_prefix}/lib/systemd/system/hyprdora-hint.service
%config(noreplace) %{_sysconfdir}/dnf/protected.d/hyprdora.conf
%config(noreplace) %{_sysconfdir}/pam.d/hyprdora-lock
%{_datadir}/glib-2.0/schemas/90_hyprdora.gschema.override
%{_datadir}/polkit-1/actions/org.hyprdora.offline-update.policy
%{_datadir}/sddm/themes/Hyprdora
%dir %{_sysconfdir}/xdg/quickshell
%{_sysconfdir}/xdg/quickshell/%{name}
%dir %{_sysconfdir}/alacritty
%config(noreplace) %{_sysconfdir}/alacritty/alacritty.toml
%config(noreplace) %{_sysconfdir}/sddm.conf.d/hyprdora.conf

%files repos
%config(noreplace) %{_sysconfdir}/yum.repos.d/hyprdora-copr.repo

%files extras

%changelog
* Mon Nov 09 2026 Grzegorz Bujański <grzegorz.bujanski@gmail.com> - 0.1.0-1
- First package
