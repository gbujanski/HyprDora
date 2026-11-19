# Notes for AI coding agents

Read `docs/development.md` before changing anything, and follow its code conventions; they apply to every change.

In short:

- English in the repository; the code explains itself, comments say why.
- Logic in QML; Python only where QML cannot do the job.
- No dead code: what a change stops using (translation keys, icons, Theme tokens, settings, functions, files) is removed in the same commit.
- Watching the local system goes through `EventSources` (`shell/base/`); scheduled downloads through `ScheduledTask` (`shell/services/`). Never a watch, poll or download timer of one's own.
- A new package the system needs is the author's decision.
- Commit only when the author asks.
