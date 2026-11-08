# Development

## Code conventions

- English everywhere in the repository: code, comments, Markdown, commit messages.
- One-line comments only where truly needed. They explain why, not what.
- Doc comments on functions: purpose, parameters, return value. JSDoc style in QML/JS, LuaLS `---@param` in Lua, docstrings in Python, a header comment in shell scripts. Required in services, libraries and scripts; trivial signal handlers are exempt.
- Logic that can run in QML is written in QML. Python is used only where QML cannot do the job, and shell only where the desktop is not running.
- Conventional Commits (`feat(shell): ...`), one branch per stage, merged to `main`.
- Documentation changes land in the same commit as the code they describe.

## Tools

`make lint` runs `qmllint`, `qmlformat`, `shellcheck`, `ruff` and `stylua` on the files that exist. Set `QT_BIN` if the Qt tools are not in `/usr/lib64/qt6/bin`.

`make dev`, adding a language and adding a keybinding are described here once they exist.
