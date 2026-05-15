log_info "Configuring SDDM theme..."

REPO_DIR="$(pwd)"

sudo cp -r "$REPO_DIR/configs/sddm/theme/Hyprdora" /usr/share/sddm/themes/

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=Hyprdora
EOF

sudo mkdir -p /var/lib/sddm
sudo tee /var/lib/sddm/state.conf > /dev/null <<EOF
[Last]
Session=hyprland.desktop
EOF

sudo chown -R sddm:sddm /var/lib/sddm

sudo authselect enable-feature with-pam-gnome-keyring > /dev/null;
sudo authselect apply-changes

sudo systemctl enable sddm.service
sudo systemctl set-default graphical.target
