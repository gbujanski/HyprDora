-- Session environment variables.

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Clipboard history in memory only: a password copied by hand never reaches the disk, and the history ends
-- with the session. Programs from Hyprland, the shell service and a terminal's cliphist all read this path.
hl.env("CLIPHIST_DB_PATH", os.getenv("XDG_RUNTIME_DIR") .. "/cliphist/db")
