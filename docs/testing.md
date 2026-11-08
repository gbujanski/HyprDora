# Testing

There are no automated tests. Qt's test tools do not work with a `qs` shell without workarounds.

Changes are checked with `make lint`, `Hyprland --verify-config` for the Lua config, and by hand. The manual checklist for hardware and interaction (Bluetooth, Wi-Fi, touchpad, monitors) is added in stage 1.
