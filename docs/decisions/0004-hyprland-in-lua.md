# 4. Hyprland config in Lua

**Context.** Keybindings should be easy to change in one place, with user overrides kept apart from packaged defaults. Hyprland 0.56 can load a Lua config.

**Decision.** The config is written in Lua. Default keybindings are a plain list in one file, a user file lists only the differences, and a small library merges them.

**Consequences.** In Lua mode, old `hyprctl dispatch` syntax and `hyprctl keyword` return errors, so the shell is ported to the new commands in the same stage.

**Rejected.** The classic config format: merging defaults with user changes, including disabling a binding, needs logic it does not have.
