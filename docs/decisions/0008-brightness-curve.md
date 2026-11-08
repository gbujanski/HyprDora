# 8. Perceptual brightness curve with a floor

**Context.** On a linear scale, the lower part of the slider was barely visible on the MacBook panel, and 0% turned the backlight off.

**Decision.** Slider level maps to backlight power as `p^3`, matching how the eye perceives brightness (CIE L\*). Level 0 means the lowest readable power, set by `brightnessMinimum`. The slider, OSD and keys share this scale through IPC.

**Rejected.** A lower limit on the linear scale: it stops the screen going dark, but steps remain uneven to the eye.
