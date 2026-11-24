# Terminal and editor

## Alacritty and tmux

Every Alacritty window opens in tmux (`/usr/libexec/hyprdora/terminal-session`), which gives it tabs and panes. All windows share one session, `main`, so programs keep running after their window closes, and the next window shows their tabs again. Each window gets a session of its own in that group, so two windows show different tabs, and opens a new tab in the folder it was started in, as Nautilus's "Open in Terminal" does. A command run with `alacritty -e` gets no tmux.

The key bindings are tmux's own. Each starts with the prefix, `Ctrl+b`, pressed and released before the key:

| Keys | Action |
|---|---|
| `Ctrl+b ?` | list every binding (`q` closes it) |
| `Ctrl+b c` | new tab |
| `Ctrl+b 1`…`9`, `Ctrl+b n` / `p` | go to a tab, next, previous |
| `Ctrl+b ,` | rename the tab |
| `Ctrl+b %` / `"` | split the pane side by side / one above the other |
| `Ctrl+b` arrow | move to the pane in that direction |
| `Ctrl+b z` | zoom the pane to the whole window and back |
| `Ctrl+b x` / `&` | close the pane / the tab |
| `Ctrl+b [` | scroll and copy mode (`q` leaves it) |
| `Ctrl+b d` | leave tmux; everything keeps running |

Shift+Enter sends what Alt+Enter does: a new line in Claude Code, and in zsh a new line within the command instead of running it. tmux cannot pass on the separate code Alacritty gives Shift+Enter, which Claude Code would otherwise ask for.

The mouse works too: the wheel scrolls the history, a click picks a tab or a pane, and Shift with the mouse selects text as Alacritty does. `/etc/tmux.conf` holds HyprDora's settings; `~/.config/tmux/tmux.conf` is read after it.

## Neovim: LazyVim

Once Neovim is installed, for example as Neovim with LazyVim on the welcome screen, [LazyVim](https://www.lazyvim.org) is its default config (`/etc/xdg/nvim/sysinit.vim`, files in `/usr/share/hyprdora/configs/nvim`). The first start fetches the plugins from GitHub, which takes a minute. It adds Python, JSON, YAML, TOML, Markdown, git files, TypeScript, Tailwind, Docker, .NET and Java, QML through Qt's `qmlls`, and [Diffview](https://github.com/sindrets/diffview.nvim) for whole commits. Language servers are installed by Mason on first use of each language.

Plugins of one's own go in `~/.config/nvim/lua/plugins/`, read after HyprDora's. An `init.lua` in `~/.config/nvim` replaces the whole config.

`Space` is the leader key. Pressing it and waiting shows what can follow; `Space s k` searches every binding.

| Keys | Action |
|---|---|
| `Space e` | project tree; changed files are marked, `]g` / `[g` jump between them, `?` lists the tree's keys |
| `Ctrl+h` / `Ctrl+l` | from the code to the tree on the left / back to the code; `Ctrl+w w` goes through every window |
| `Space Space` | find a file by name |
| `Space /` | search text in the project |
| `Space s w` | search the word under the cursor |
| `Space ,` / `Space f r` | open files / recent files |
| `Shift+h` / `Shift+l`, `Space b d` | previous / next open file, close it |
| `gd`, `gr`, `K` | definition, references, documentation of the symbol under the cursor |
| `Space s d` | problems in the project |
| `]h` / `[h` | next / previous changed block; changed lines are marked beside the line numbers |
| `Space g h p` | show what a changed block was before |
| `Space g h b` | who changed this line, and in which commit |
| `Space g s`, `Space g l`, `Space g f` | git status, commits, this file's history |
| `Space g g` | lazygit |
| `Space g v` | Diffview: every changed file and its changes beside the old version; again to close |
| `Space g V` | Diffview: this file's commits |
| `Space -` / `Space \|`, `Ctrl+h/j/k/l` | split below / right, move between splits |
| `Space q q` | quit |

Lines are marked against the last commit. To review a commit or a branch instead: `:Gitsigns change_base HEAD~1` marks what changed since the commit before (`:Gitsigns reset_base` goes back), and `:DiffviewOpen main...HEAD` shows everything a branch changed since it left `main`.

`:Lazy` updates the plugins, `:LazyExtras` turns more of LazyVim's extras on, `:Mason` shows the language servers, `:lsp restart` restarts them after a file changed outside the editor, and `:checkhealth` tells what is missing.

## Zed

[Zed](https://zed.dev) comes from Flathub (`dev.zed.Zed`), chosen on the welcome screen like VS Code. It can run the system's tools, so its terminal, git and language servers behave as outside it.
