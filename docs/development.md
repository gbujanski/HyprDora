# Development

## Running the shell

`make dev` starts the shell from the repository in a nested Hyprland window, without touching the running session. `ALT` is the modifier there, because the outer session captures `SUPER`:

| Key | Action |
|---|---|
| `ALT + A` | action center |
| `ALT + Escape` | power page |
| `ALT + Return` | terminal |
| `ALT + Q` | close window |

Its config files live in `build/dev/config`, so saving monitors or a wallpaper does not change the real ones. `settings.json` is copied there on the first run.

## Settings

`~/.config/hyprdora/settings.json` overrides the defaults in `shell/config/Settings.qml`. Every key is optional, and saving the file applies it.

```json
{
  "language": "auto",
  "weather": { "place": "Warsaw", "latitude": 52.23, "longitude": 21.01 },
  "terminalCommand": ["alacritty", "--class", "systui", "-e"],
  "brightnessMinimum": 0.016,
  "calendarScrollDelay": 100
}
```

Weather stays hidden until `weather` has coordinates.

## Adding a language

Copy `shell/i18n/en.json` to `shell/i18n/<code>.json` and translate the values. A missing key falls back to English.

Plurals are objects. Languages with simple plurals need `one` and `other`. If a language needs other forms, add its rule to `pluralRules` in `shell/config/I18n.qml`.

```json
"notifications.count": { "one": "{count} notification", "other": "{count} notifications" }
```

In QML: `I18n.t("notifications.count", { count: 3 })`.

## Code conventions

- English everywhere in the repository: code, comments, Markdown, commit messages.
- One-line comments only where truly needed. They explain why, not what.
- Doc comments on functions: purpose, parameters, return value. JSDoc style in QML/JS, LuaLS `---@param` in Lua, docstrings in Python, a header comment in shell scripts. Required in services, libraries and scripts; trivial signal handlers are exempt.
- Logic that can run in QML is written in QML. Python is used only where QML cannot do the job, and shell only where the desktop is not running.
- Conventional Commits (`feat(shell): ...`), one branch per stage, merged to `main`.
- Documentation changes land in the same commit as the code they describe.

## Tools

`make lint` runs `qmllint`, `qmlformat`, `shellcheck`, `ruff` and `stylua` on the files that exist. Set `QT_BIN` if the Qt tools are not in `/usr/lib64/qt6/bin`.
