import QtQuick
import qs.config
import qs.components

// Times after which the screen dims, locks and the laptop suspends. Hovering a row opens its choices beside it.
Column {
    id: root

    // The settings menu, which shows the choices.
    property Item menu: null

    readonly property var steps: [0, 60, 120, 180, 240, 300, 600, 900, 1800, 3600]
    readonly property var rows: [
        {
            key: "dim",
            setting: "idleDim",
            title: I18n.t("idle.dim")
        },
        {
            key: "lock",
            setting: "idleLock",
            title: I18n.t("idle.lock")
        },
        {
            key: "suspend",
            setting: "idleSuspend",
            title: I18n.t("idle.suspend")
        }
    ]

    /**
     * Returns the label for a time.
     * @param {int} seconds  time in seconds, 0 for off
     * @returns {string}
     */
    function label(seconds) {
        if (seconds === 0)
            return I18n.t("idle.never");
        return seconds % 60 === 0 ? I18n.t("idle.minutes", {
            count: seconds / 60
        }) : I18n.t("idle.seconds", {
            count: seconds
        });
    }

    /**
     * Returns the choices for a step, keeping a value set outside this list.
     * @param {int} current  current value in seconds
     * @returns {array} [{ value, label }]
     */
    function options(current) {
        const values = steps.includes(current) ? steps : [...steps, current].sort((a, b) => a - b);
        return values.map(seconds => ({
                    value: seconds,
                    label: label(seconds)
                }));
    }

    spacing: 2

    Repeater {
        model: root.rows

        ChoiceRow {
            required property var modelData
            readonly property int value: Settings[modelData.setting]

            width: root.width
            menu: root.menu
            title: modelData.title
            valueText: root.label(value)
            options: root.options(value)
            current: value
            onSelected: v => Settings.setIn("idle", modelData.key, v)
        }
    }
}
