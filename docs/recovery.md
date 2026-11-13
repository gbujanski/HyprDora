# Recovery

The system part of HyprDora can be returned to an earlier state in one command. Files in the home directory are never changed by it.

## When something breaks

1. If the desktop does not start, press `Ctrl+Alt+F3`. The console shows a reminder of the command before you log in.
2. Log in and run `hyprdora rollback`.
3. Pick a snapshot from the list, usually the one marked *before* the `dnf` command that broke things, and confirm.
4. Let the computer restart.

`hyprdora --help` (or `-h`) lists every command, `hyprdora snapshots` only shows the list, and `hyprdora --version` (or `-v`) shows the installed version. Messages follow the system language: Polish or English, and English for any other language.

## How it works

- **Snapshots.** snapper takes one before and one after every `dnf` transaction, and more can be taken by hand from the settings. The daily cleanup keeps the 10 newest (4 for important ones, such as a kernel update) and the first one, of the freshly installed system. They cover only the system subvolume `root`; `/home` is a separate subvolume and is not included.
- **Space.** Btrfs quota lets snapper measure snapshots. They may use at most 10% of the disk and must leave 20% free; when a limit is hit, snapper deletes the oldest ones, down to 2 per kind. Docker data, virtual machine images and Flatpaks live in their own subvolumes, so snapshots leave them out.
- **Protection.** `/etc/dnf/protected.d/hyprdora.conf` protects `hyprdora`, `snapper` and `btrfs-progs`. `dnf` refuses any change that would remove them, which also stops changes that would take the login screen, Hyprland or the shell with them.
- **Rollback.** `hyprdora rollback` needs only `btrfs`, not snapper, because a broken transaction can remove snapper itself. It makes a writable copy of the chosen snapshot, moves the nested subvolumes (the snapshots, Docker data) into it, and puts it in place of `root`. The replaced system is kept as `root.replaced-<date>`, so a rollback can be undone with another one; only the newest replaced system is kept.
- **Kernels.** `/boot` is a separate ext4 partition and is not in snapshots. If the newest kernel has no modules in the chosen snapshot, `hyprdora rollback` makes the newest kernel that does the default boot entry.

## Verified

In a virtual machine installed from the ISO: removing SDDM with `dnf` took 316 packages, including snapper, so `snapper undochange` was impossible; the subvolume swap restored the whole system. `hyprdora rollback` removed a package installed after the chosen snapshot, and the system started normally. The kernel case has not been tested.

## Changing the snapshot settings on a running system

`snapperd` keeps the configuration in memory, so `snapper --no-dbus set-config` updates the file but the daemon still shows the old values. Use `snapper set-config` without `--no-dbus`, or restart `snapperd` after editing. The installer runs without the daemon, so it uses `--no-dbus`.
