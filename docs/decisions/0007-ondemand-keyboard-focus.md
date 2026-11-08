# 7. OnDemand keyboard focus for panels

**Context.** With the action center or calendar open, the bar did not react to clicks. With `WlrKeyboardFocus.Exclusive`, Hyprland routes all clicks to that layer.

**Decision.** Panels use `WlrKeyboardFocus.OnDemand`. The bar stays clickable, so its icons can toggle panels.

**Rejected.** `Exclusive` for panels. It is still right for the display confirmation dialog, which must be answered before anything else.
