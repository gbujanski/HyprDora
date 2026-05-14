REPO_DIR="$(pwd)"
CONFIG_DIR="$HOME/.config"

cp -r $REPO_DIR/configs/scripts $CONFIG_DIR/hyprdora

chmod +x $CONFIG_DIR/hyprdora/scripts/*
