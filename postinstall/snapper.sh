log_info "Setting up Snapper for Btrfs snapshots..."

# if snapper config already exists, skip creation
if [ -f "/etc/snapper/configs/root" ]; then
    log_info "Snapper config for root already exists. Skipping creation."
else
    sudo snapper -c root create-config / &> /dev/null;
fi

# --- Timeline Retention Settings ---
# Disable hourly, monthly, and yearly snapshots to save space
sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="0"/' /etc/snapper/configs/root
sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

# Keep snapshots for exactly the last 7 days and 1 weekly snapshot
sudo sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="1"/' /etc/snapper/configs/root

# --- DNF (Installation/Update) Snapshot Settings ---
# Limit the number of pre/post installation snapshots created by package manager
sudo sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' /etc/snapper/configs/root
sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="3"/' /etc/snapper/configs/root

sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

sudo grub2-mkconfig -o /boot/grub2/grub.cfg &> /dev/null;
