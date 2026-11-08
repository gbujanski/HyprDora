# 8. Perceptual brightness curve with a floor

**Context.** The slider used the curve from Hyprland's example config (`brightnessctl -e4 -n2`). On the MacBook panel, the bottom 20% of the slider gave a practically black screen, at 0.07-0.14% of backlight power.

**Decision.** Slider level maps to backlight power as `p^3`, matching how the eye perceives brightness (CIE L\*). Level 0 means the lowest readable power, set by `brightnessMinimum`. The slider, OSD and keys share this scale through IPC.

**Rejected.** Keeping the example curve and only limiting its lower end: most of the slider would still sit in a range where little changes on screen.
