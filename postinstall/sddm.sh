REPO_DIR="$(pwd)"

sudo cp -r "$REPO_DIR/configs/sddm/theme/Hyprdora" /usr/share/sddm/themes/

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=Hyprdora
EOF

sudo mkdir -p /var/lib/sddm
sudo tee /var/lib/sddm/state.conf <<EOF
[Last]
Session=hyprland.desktop
EOF
sudo chown -R sddm:sddm /var/lib/sddm

sudo authselect enable-feature with-pam-gnome-keyring
sudo authselect apply-changes

sudo systemctl enable sddm.service
sudo systemctl set-default graphical.target
