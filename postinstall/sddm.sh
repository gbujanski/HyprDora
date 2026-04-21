REPO_DIR="$(pwd)"

sudo cp -r "$REPO_DIR/configs/sddm/theme/Hyprdora" /usr/share/sddm/themes/

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=Hyprdora
EOF

sudo authselect enable-feature with-gnome-keyring
sudo authselect apply-changes