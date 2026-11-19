import QtQuick
import qs.config
import qs.components
import qs.services

// The form for a new event on a day: title, time, reminders, repeat, calendar, place, description and
// attendees. Its fields scroll when they do not fit; the buttons stay in view.
Column {
    id: root

    required property var day
    // Height the fields may take before they scroll.
    property real maxFieldsHeight: 100000
    // Height of the buttons, with the gap above them.
    readonly property real buttonsHeight: formButtons.height + spacing

    signal cancelled

    property string summary: ""
    property string location: ""
    property string description: ""
    property string attendees: ""
    property bool allDay: false
    property int fromMinutes: 9 * 60
    property int toMinutes: 10 * 60
    property string calendar: CalendarEvents.preferredCalendar()
    property string repeat: ""
    property bool repeatUntil: false
    property date untilDate: new Date()
    property string formError: ""
    // A reminder when the event starts, and others before it: [{ amount, unit }].
    property bool remindAtStart: true
    property var reminders: []
    readonly property var units: [
        {
            value: 1,
            label: I18n.t("calendar.unit.minutes")
        },
        {
            value: 60,
            label: I18n.t("calendar.unit.hours")
        },
        {
            value: 1440,
            label: I18n.t("calendar.unit.days")
        },
        {
            value: 10080,
            label: I18n.t("calendar.unit.weeks")
        }
    ]

    /**
     * Changes one reminder before the start.
     * @param {int} index  position in reminders
     * @param {object} changes  { amount } or { unit }
     */
    function setReminder(index, changes) {
        reminders = reminders.map((r, i) => i === index ? Object.assign({}, r, changes) : r);
    }

    readonly property var repeatOptions: [
        {
            value: "",
            label: I18n.t("calendar.repeat.none")
        },
        {
            value: "DAILY",
            label: I18n.t("calendar.repeat.daily")
        },
        {
            value: "WEEKLY",
            label: I18n.t("calendar.repeat.weekly")
        },
        {
            value: "WEEKLY2",
            label: I18n.t("calendar.repeat.biweekly")
        },
        {
            value: "MONTHLY",
            label: I18n.t("calendar.repeat.monthly")
        },
        {
            value: "YEARLY",
            label: I18n.t("calendar.repeat.yearly")
        }
    ]

    /** Fills the form with fresh values. */
    function reset() {
        summary = "";
        location = "";
        description = "";
        attendees = "";
        allDay = false;
        repeat = "";
        repeatUntil = false;
        remindAtStart = true;
        reminders = [
            {
                amount: 15,
                unit: 1
            }
        ];
        // The next full hour, for an event added today.
        const now = new Date();
        const today = CalendarEvents.key(now) === CalendarEvents.key(day);
        fromMinutes = today ? Math.min(23 * 60, (now.getHours() + 1) * 60) : 9 * 60;
        toMinutes = Math.min(fromMinutes + 60, 23 * 60 + 59);
        const until = new Date(day);
        until.setMonth(until.getMonth() + 1);
        untilDate = until;
        calendar = CalendarEvents.preferredCalendar();
        formError = "";
        CalendarEvents.error = "";
    }

    /**
     * Formats minutes after midnight on the selected day as a local ISO time.
     * @param {int} minutes  minutes after midnight
     * @returns {string}
     */
    function stamp(minutes) {
        return `${CalendarEvents.key(day)}T${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
    }

    /** Checks the form and sends the new event. */
    function save() {
        if (summary.trim() === "" || calendar === "")
            return;
        // The offline calendar has nothing to send invitations with.
        const addresses = CalendarEvents.isLocal(calendar) ? [] : attendees.split(/[,;\s]+/).map(a => a.trim()).filter(Boolean);
        const wrong = addresses.filter(a => !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(a));
        if (wrong.length > 0) {
            formError = I18n.t("calendar.error.address", {
                address: wrong[0]
            });
            return;
        }
        formError = "";
        const next = new Date(day);
        next.setDate(next.getDate() + 1);
        CalendarEvents.create(calendar, {
            summary: summary.trim(),
            location: location.trim(),
            description: description.trim(),
            allDay: allDay,
            start: allDay ? CalendarEvents.key(day) : stamp(fromMinutes),
            end: allDay ? CalendarEvents.key(next) : stamp(toMinutes),
            repeat: repeat === "" ? null : {
                freq: repeat === "WEEKLY2" ? "WEEKLY" : repeat,
                interval: repeat === "WEEKLY2" ? 2 : 1,
                until: repeatUntil ? CalendarEvents.key(untilDate) : ""
            },
            attendees: addresses,
            // Minutes before the start, without repeats.
            reminders: [...new Set([...(remindAtStart ? [0] : []), ...reminders.map(r => r.amount * r.unit)])]
        });
    }

    spacing: 6

    ScrollArea {
        id: formView

        width: root.width
        height: visible ? Math.min(formFields.implicitHeight, root.maxFieldsHeight) : 0
        contentHeight: formFields.implicitHeight

        Column {
            id: formFields
            width: formView.usableWidth
            spacing: 8

            TextField {
                width: parent.width
                placeholder: I18n.t("calendar.titlePlaceholder")
                text: root.summary
                onTextChanged: root.summary = text
                onAccepted: root.save()
                onCancelled: root.cancelled()
                onVisibleChanged: if (visible)
                    focusInput()
            }

            Item {
                width: parent.width
                height: 30

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.capitalized(I18n.t("calendar.allDay"))
                    color: Theme.muted
                }

                Switch {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    checked: root.allDay
                    onToggled: root.allDay = !root.allDay
                }
            }

            Row {
                visible: !root.allDay
                spacing: 18

                Row {
                    spacing: 8

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("automations.from")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TimeInput {
                        minutes: root.fromMinutes
                        // An end at or before the new start moves an hour after it.
                        onEdited: value => {
                            root.fromMinutes = value;
                            if (root.toMinutes <= value)
                                root.toMinutes = Math.min(value + 60, 23 * 60 + 59);
                        }
                    }
                }

                Row {
                    spacing: 8

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("automations.to")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TimeInput {
                        minutes: root.toMinutes
                        // The end stays after the start.
                        onEdited: value => root.toMinutes = Math.max(value, Math.min(root.fromMinutes + 1, 23 * 60 + 59))
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("calendar.reminder.atStart")
                    color: Theme.muted
                }

                Switch {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    checked: root.remindAtStart
                    onToggled: root.remindAtStart = !root.remindAtStart
                }
            }

            Label {
                visible: root.reminders.length > 0
                text: I18n.t("calendar.reminder.before")
                color: Theme.muted
            }

            // Each reminder before the start: an amount and its unit, as in Google Calendar.
            Repeater {
                model: root.reminders

                Item {
                    id: reminderRow

                    required property var modelData
                    required property int index

                    width: parent.width
                    height: amount.implicitHeight

                    NumberSegment {
                        id: amount
                        anchors.verticalCenter: parent.verticalCenter
                        value: reminderRow.modelData.amount
                        from: 1
                        to: 60
                        digits: 2
                        pad: false
                        onEdited: v => root.setReminder(reminderRow.index, {
                                amount: v
                            })
                    }

                    SegmentedControl {
                        anchors {
                            left: amount.right
                            right: removeReminder.left
                            leftMargin: 8
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        options: root.units
                        currentValue: reminderRow.modelData.unit
                        onSelected: value => root.setReminder(reminderRow.index, {
                                unit: value
                            })
                    }

                    IconButton {
                        id: removeReminder
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        icon: Icons.close
                        iconColor: Theme.muted
                        tooltip: I18n.t("calendar.reminder.remove")
                        onClicked: root.reminders = root.reminders.filter((r, i) => i !== reminderRow.index)
                    }
                }
            }

            TextButton {
                text: I18n.t("calendar.reminder.add")
                onClicked: root.reminders = [...root.reminders,
                    {
                        amount: 15,
                        unit: 1
                    }
                ]
            }

            Dropdown {
                width: parent.width
                title: I18n.t("calendar.repeat.title")
                options: root.repeatOptions
                currentValue: root.repeat
                onSelected: value => root.repeat = value
            }

            Item {
                width: parent.width
                height: 30
                visible: root.repeat !== ""

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("calendar.repeat.until")
                    color: Theme.muted
                }

                Switch {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    checked: root.repeatUntil
                    onToggled: root.repeatUntil = !root.repeatUntil
                }
            }

            DateInput {
                anchors.right: parent.right
                visible: root.repeat !== "" && root.repeatUntil
                date: root.untilDate
                // The last day cannot come before the event itself.
                onEdited: value => root.untilDate = value < root.day ? new Date(root.day) : value
            }

            Dropdown {
                width: parent.width
                visible: CalendarEvents.calendars.length > 1
                title: I18n.t("calendar.calendar")
                options: CalendarEvents.calendars.map(c => ({
                            value: c.href,
                            label: c.name
                        }))
                currentValue: root.calendar
                onSelected: value => root.calendar = value
            }

            TextField {
                width: parent.width
                placeholder: I18n.t("calendar.locationPlaceholder")
                text: root.location
                onTextChanged: root.location = text
                onAccepted: root.save()
                onCancelled: root.cancelled()
            }

            // A few lines of description, without the look of a big text box.
            Rectangle {
                width: parent.width
                height: Math.max(34, Math.min(descriptionEdit.contentHeight + 16, 90))
                radius: Theme.radius
                color: Theme.surface
                border.width: 1
                border.color: descriptionEdit.activeFocus ? Theme.accent : Theme.surfaceHover

                Flickable {
                    id: descriptionFlick
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 8
                        topMargin: 8
                        bottomMargin: 8
                    }
                    contentWidth: width
                    contentHeight: descriptionEdit.contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: descriptionEdit
                        width: descriptionFlick.width
                        text: root.description
                        wrapMode: TextEdit.Wrap
                        color: Theme.foreground
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        onTextChanged: root.description = text
                        onCursorRectangleChanged: {
                            if (cursorRectangle.y + cursorRectangle.height > descriptionFlick.contentY + descriptionFlick.height)
                                descriptionFlick.contentY = cursorRectangle.y + cursorRectangle.height - descriptionFlick.height;
                            else if (cursorRectangle.y < descriptionFlick.contentY)
                                descriptionFlick.contentY = cursorRectangle.y;
                        }
                    }

                    Label {
                        visible: descriptionEdit.text === ""
                        text: I18n.t("calendar.descriptionPlaceholder")
                        color: Theme.dim
                    }
                }
            }

            TextField {
                width: parent.width
                visible: !CalendarEvents.isLocal(root.calendar)
                placeholder: I18n.t("calendar.attendeesPlaceholder")
                text: root.attendees
                onTextChanged: root.attendees = text
                onAccepted: root.save()
                onCancelled: root.cancelled()
            }
        }
    }

    Column {
        id: formButtons
        width: root.width
        spacing: 8

        ErrorBanner {
            width: parent.width
            text: root.formError || CalendarEvents.error
        }

        Row {
            anchors.right: parent.right
            spacing: 6

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: CalendarEvents.busy === "create"
            }

            TextButton {
                text: I18n.t("common.cancel")
                onClicked: root.cancelled()
            }

            TextButton {
                text: I18n.t("calendar.save")
                primary: true
                active: root.summary.trim() !== "" && CalendarEvents.busy === ""
                onClicked: root.save()
            }
        }
    }
}
