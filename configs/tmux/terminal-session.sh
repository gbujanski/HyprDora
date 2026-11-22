#!/bin/bash
# Alacritty's shell: every window joins the tmux session "main", whose programs keep running after a window
# closes. The first window makes it. Each later one gets a session of its own in the same group, which shares
# the tabs but shows its own, and opens a new tab in the folder it was started in, as "Open in Terminal" does.
# Without tmux, the login shell starts as before.
command -v tmux >/dev/null || exec "${SHELL:-/bin/bash}" -l
# A terminal opened from inside tmux starts its own window rather than nesting.
unset TMUX
if tmux has-session -t main 2>/dev/null; then
    exec tmux new-session -t main \; set-option destroy-unattached on \; new-window -c "$PWD"
fi
exec tmux new-session -s main -c "$PWD"
