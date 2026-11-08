pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Translations from i18n/<language>.json. Adding a language means adding one file.
// qsTr() cannot be used: it needs a QTranslator installed from C++.
Singleton {
    id: root

    readonly property string requested: Settings.language === "auto" ? Qt.locale().name.split("_")[0] : Settings.language
    property var english: null
    property var strings: ({})
    property bool loaded: false

    readonly property string language: loaded ? requested : "en"
    readonly property var locale: Qt.locale(language)

    // Forms not listed here use "one" for 1 and "other" for everything else.
    readonly property var pluralRules: ({
        pl: n => {
            if (n === 1) return "one";
            const tens = n % 100;
            return n % 10 >= 2 && n % 10 <= 4 && (tens < 12 || tens > 14) ? "few" : "many";
        }
    })

    /**
     * Returns a translated string, falling back to English and then to the key.
     * @param {string} key  flat translation key
     * @param {object} values  placeholder values; `count` also selects the plural form
     * @returns {string}
     */
    function t(key, values) {
        const entry = strings[key] ?? english?.[key];
        if (entry === undefined) {
            if (english === null) return "";
            console.warn("i18n: missing key:", key);
            return key;
        }
        const text = typeof entry === "string" ? entry : pluralOf(entry, values?.count ?? 0);
        return text.replace(/\{(\w+)\}/g, (match, name) => values?.[name] ?? match);
    }

    /**
     * Picks the plural form for a number in the active language.
     * @param {object} forms  plural forms such as { one, few, many, other }
     * @param {int} count  number being described
     * @returns {string}
     */
    function pluralOf(forms, count) {
        const rule = pluralRules[language];
        const form = rule ? rule(count) : count === 1 ? "one" : "other";
        return forms[form] ?? forms.other;
    }

    /**
     * Returns a capitalized month name.
     * @param {int} month  month index, 0..11
     * @returns {string}
     */
    function monthName(month) {
        return capitalized(locale.standaloneMonthName(month, Locale.LongFormat));
    }

    /**
     * Returns a capitalized short day name without a trailing period.
     * @param {int} day  day of the week, 0 is Sunday
     * @returns {string}
     */
    function shortDayName(day) {
        return capitalized(locale.standaloneDayName(day, Locale.ShortFormat).replace(".", ""));
    }

    /**
     * Uppercases the first letter of a string.
     * @param {string} text  input text
     * @returns {string}
     */
    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    /**
     * Parses a translation file.
     * @param {string} text  file contents
     * @returns {object} translations, empty when the file is invalid
     */
    function parsed(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("i18n: invalid translation file");
            return {};
        }
    }

    FileView {
        path: Quickshell.shellPath("i18n/en.json")
        blockLoading: true
        onLoaded: root.english = root.parsed(text())
    }

    FileView {
        path: Quickshell.shellPath(`i18n/${root.requested}.json`)
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.strings = root.parsed(text());
            root.loaded = true;
        }
        onLoadFailed: {
            root.strings = {};
            root.loaded = false;
        }
    }
}
