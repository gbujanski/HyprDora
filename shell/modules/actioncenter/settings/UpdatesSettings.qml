import QtQuick
import qs.config
import qs.components
import qs.services

// How the system looks for updates: how often, a pause, when ordinary updates show on the bar, whether they
// download in the background, and a check now with when the last one was. How often, the pause and the
// download hold for the whole computer, so changing them asks for the administrator password in a window of
// its own, which the action center would cover, so it closes first. A pause is confirmed before that: while
// it lasts nothing looks for updates or reminds of them, not even security ones.
Column {
    id: root

    // The settings menu, which shows the choices.
    property Item menu: null
    // A pause chosen and waiting for confirmation, or null.
    property var pendingPause: null
    // What the last check by hand came to: "", "none" or "failed".
    property string checkResult: ""

    // Every 3 hours (and 10 minutes after start, Fedora's own timer), once a day, once a week.
    readonly property var intervals: ["often", "daily", "weekly"].map(value => ({
                value: value,
                label: I18n.t(`updates.settings.interval.${value}`)
            }))
    // Hours, then days, in seconds, between until restart and for good.
    readonly property var pauses: ["restart", 3600, 4 * 3600, 12 * 3600, 24 * 3600, 3 * 24 * 3600, 7 * 24 * 3600, "always"].map(value => ({
                value: value,
                label: pauseLabel(value)
            }))

    /**
     * Returns the label of a pause choice.
     * @param {var} value  "restart", "always", or seconds
     * @returns {string}
     */
    function pauseLabel(value) {
        if (value === "restart" || value === "always")
            return I18n.t(`updates.settings.pause.${value}`);
        return value < 24 * 3600 ? I18n.t("updates.settings.pause.hours", {
            count: value / 3600
        }) : I18n.t("updates.settings.pause.days", {
            count: value / (24 * 3600)
        });
    }

    // Days ordinary updates wait before the bar shows them.
    readonly property var reminders: [0, 1, 7].map(days => ({
                value: days,
                label: I18n.t(`updates.settings.reminder.${days}`)
            }))

    /**
     * When the system last looked for updates: today or yesterday with the time, or the date and time.
     * @returns {string} empty when not known
     */
    function lastCheckedText() {
        if (Updates.lastChecked === 0)
            return "";
        const when = new Date(Updates.lastChecked);
        const time = when.toLocaleTimeString(I18n.locale, "HH:mm");
        const days = Math.round((new Date().setHours(0, 0, 0, 0) - new Date(when).setHours(0, 0, 0, 0)) / 86400000);
        const day = days === 0 ? I18n.t("updates.settings.today", {
            time: time
        }) : days === 1 ? I18n.t("updates.settings.yesterday", {
            time: time
        }) : `${when.toLocaleDateString(I18n.locale, "d MMM")}, ${time}`;
        return I18n.t("updates.settings.lastChecked", {
            time: day
        });
    }

    /** The pause as it stands: none, until restart, for good, or until a time. */
    function pauseState() {
        if (!Updates.paused)
            return I18n.t("updates.settings.notPaused");
        if (Updates.pausedUntilRestart)
            return I18n.t("updates.settings.pause.restart");
        if (Updates.pausedForGood)
            return I18n.t("updates.settings.pause.always");
        return I18n.t("updates.settings.pausedUntil", {
            time: new Date(Updates.pauseEnd).toLocaleString(I18n.locale, "d MMM, HH:mm")
        });
    }

    spacing: 2

    Connections {
        target: Updates
        function onCheckedNow(failed) {
            if (!failed && Updates.count > 0) {
                root.checkResult = "";
                Panels.open("updates", null);
            } else {
                root.checkResult = failed ? "failed" : "none";
            }
        }
    }

    ChoiceRow {
        width: root.width
        menu: root.menu
        title: I18n.t("updates.settings.interval")
        valueText: I18n.t(`updates.settings.interval.${Updates.interval}`)
        options: root.intervals
        current: Updates.interval
        onSelected: value => {
            if (value === Updates.interval)
                return;
            Panels.close("actioncenter");
            Updates.setInterval(value);
        }
    }

    ChoiceRow {
        width: root.width
        menu: root.menu
        title: I18n.t("updates.settings.pause")
        valueText: root.pauseState()
        // While paused, resuming comes first.
        options: Updates.paused ? [
            {
                value: "resume",
                label: I18n.t("updates.settings.resume")
            },
            ...root.pauses] : root.pauses
        current: null
        onSelected: value => {
            if (value === "resume") {
                Panels.close("actioncenter");
                Updates.resume();
            } else {
                root.pendingPause = value;
            }
        }
    }

    // Before pausing: what it means, and the choice to go on.
    Column {
        width: root.width
        visible: root.pendingPause !== null
        spacing: 10
        topPadding: 6
        bottomPadding: 6

        Label {
            width: parent.width
            leftPadding: 8
            rightPadding: 8
            // "Until restart, nothing will look for updates…"
            text: root.pendingPause === null ? "" : I18n.t("updates.settings.pauseWarning", {
                time: root.pauseLabel(root.pendingPause)
            })
            color: Theme.warning
            wrapMode: Text.WordWrap
        }

        Row {
            anchors.right: parent.right
            spacing: 6

            ConfirmButton {
                text: I18n.t("common.cancel")
                onClicked: root.pendingPause = null
            }

            ConfirmButton {
                text: I18n.t("updates.settings.pauseConfirm")
                selected: true
                danger: true
                onClicked: {
                    const value = root.pendingPause;
                    root.pendingPause = null;
                    Panels.close("actioncenter");
                    Updates.setPause(value);
                }
            }
        }
    }

    // Its own setting, so it changes at once, with no password.
    ChoiceRow {
        width: root.width
        menu: root.menu
        title: I18n.t("updates.settings.reminder")
        note: I18n.t("updates.settings.reminderNote")
        valueText: I18n.t(`updates.settings.reminder.${Settings.updateReminderDays}`)
        options: root.reminders
        current: Settings.updateReminderDays
        onSelected: value => Settings.setIn("updates", "reminderDays", value)
    }

    // Off, updates are still looked for; they download when installed.
    ItemRow {
        width: root.width
        title: I18n.t("updates.settings.download")
        onClicked: {
            Panels.close("actioncenter");
            Updates.setBackgroundDownload(!Updates.backgroundDownload);
        }

        trailing: Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Updates.backgroundDownload
            onToggled: {
                Panels.close("actioncenter");
                Updates.setBackgroundDownload(!Updates.backgroundDownload);
            }
        }
    }

    ItemRow {
        width: root.width
        icon: Icons.refresh
        title: I18n.t("updates.settings.checkNow")
        subtitle: Updates.checkingNow ? I18n.t("updates.settings.checking") : root.checkResult !== "" ? I18n.t(`updates.settings.check.${root.checkResult}`) : root.lastCheckedText()
        interactive: !Updates.checkingNow
        onClicked: {
            root.checkResult = "";
            Updates.checkNow();
        }

        trailing: Spinner {
            anchors.verticalCenter: parent.verticalCenter
            running: Updates.checkingNow
        }
    }
}
