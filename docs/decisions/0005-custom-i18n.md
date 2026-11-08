# 5. Custom i18n instead of qsTr

**Context.** Adding a language should be trivial. Qt's `qsTr()` needs a `QTranslator` installed from C++. The `qs` binary does not use one and QML cannot install it, so `qsTr()` would always return the source text.

**Decision.** A small `I18n` singleton reads flat JSON files from `shell/i18n/`. Adding a language means adding one file. Plurals are objects with `one`/`few`/`many`/`other` forms, a missing key falls back to English, and dates come from `Qt.locale()`.

**Rejected.** `qsTr()` with `.qm` files: it does not work under `qs`.
