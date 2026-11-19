import QtQuick
import qs.config
import qs.components
import qs.services

// The selected day's events. A click on one shows its description and attendees; the bin deletes it,
// asking whether only that occurrence or the whole series goes for a repeating one. The "+" opens a form
// that replaces the list while it is open.
Column {
    id: root

    required property var day
    // Today, to name an empty day today or tomorrow.
    property date today: new Date()
    // Height the list of events, or the form's fields, may take before they scroll, and the height of
    // everything else here.
    property real maxListHeight: 100000
    // Counted from the parts themselves: deriving it from the total height, which includes the list, would
    // make the list's height depend on itself.
    readonly property real chromeHeight: {
        const parts = [dayHeader, offlineLabel, emptyLabel, deleteError].filter(item => item.visible);
        const gaps = parts.length + (listView.visible || form.visible ? 1 : 0) - 1;
        return parts.reduce((sum, item) => sum + item.height, 0) + spacing * Math.max(0, gaps) + (form.visible ? form.buttonsHeight : 0);
    }

    readonly property var events: CalendarEvents.on(day)
    property bool adding: false
    // The event whose details are open, and the one waiting for delete confirmation, by key().
    property string expanded: ""
    property string confirming: ""
    // The event and its row while the delete question shows beside the panel.
    readonly property var confirmEvent: confirming === "" ? null : (events.find(e => key(e) === confirming) ?? null)
    property Item confirmRow: null

    /**
     * Identifies one occurrence of an event in the list.
     * @param {object} event  event from CalendarEvents
     * @returns {string}
     */
    function key(event) {
        return `${event.href}|${event.start}`;
    }

    /** Opens the form with fresh values. */
    function startAdding() {
        form.reset();
        adding = true;
    }

    onDayChanged: {
        adding = false;
        confirming = "";
        expanded = "";
    }

    spacing: 6

    // A finished change closes the form or the confirmation.
    Connections {
        target: CalendarEvents
        function onBusyChanged() {
            if (CalendarEvents.busy === "" && CalendarEvents.error === "") {
                root.adding = false;
                root.confirming = "";
            }
        }
    }

    Item {
        id: dayHeader
        width: root.width
        height: 28

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.day.toLocaleDateString(I18n.locale, "dddd, d MMMM")
            font.weight: Font.DemiBold
        }

        IconButton {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            visible: !root.adding && CalendarEvents.calendars.length > 0
            icon: Icons.plus
            iconColor: Theme.accent
            tooltip: I18n.t("calendar.add")
            onClicked: root.startAdding()
        }
    }

    Label {
        id: offlineLabel
        width: root.width
        visible: CalendarEvents.offline
        text: I18n.t("calendar.offline")
        color: Theme.warning
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    EmptyState {
        id: emptyLabel
        width: root.width
        visible: root.events.length === 0 && !root.adding
        text: {
            const days = Math.round((new Date(root.day.getFullYear(), root.day.getMonth(), root.day.getDate()) - new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())) / 86400000);
            return days === 0 ? I18n.t("calendar.noEventsToday") : days === 1 ? I18n.t("calendar.noEventsTomorrow") : I18n.t("calendar.noEvents");
        }
    }

    // The list hides while an event is added, so the form is always in view.
    ScrollArea {
        id: listView

        width: root.width
        visible: !root.adding && root.events.length > 0
        height: visible ? Math.min(listColumn.implicitHeight, root.maxListHeight) : 0
        contentHeight: listColumn.implicitHeight

        Column {
            id: listColumn

            width: listView.usableWidth
            spacing: 4

            Repeater {
                model: root.events

                Rectangle {
                    id: row

                    required property var modelData
                    readonly property string rowKey: root.key(modelData)
                    readonly property bool open: root.expanded === rowKey
                    readonly property bool confirming: root.confirming === rowKey

                    width: listColumn.width
                    height: rowContent.implicitHeight + 12
                    radius: Theme.radius
                    color: open || confirming || rowArea.containsMouse ? Theme.surface : "transparent"
                    border.width: open ? 1 : 0
                    border.color: Theme.surfaceHover

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = row.open ? "" : row.rowKey
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            leftMargin: 4
                            top: parent.top
                            topMargin: 8
                        }
                        width: 4
                        height: 28
                        radius: width / 2
                        color: row.modelData.color || Theme.accent
                    }

                    Column {
                        id: rowContent

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 18
                            rightMargin: 6
                            topMargin: 6
                        }
                        spacing: 4

                        Item {
                            width: parent.width
                            height: titleColumn.implicitHeight

                            Column {
                                id: titleColumn
                                anchors {
                                    left: parent.left
                                    right: actions.left
                                    rightMargin: 6
                                }
                                spacing: 1

                                Label {
                                    width: parent.width
                                    text: row.modelData.summary
                                    elide: Text.ElideRight
                                }

                                Label {
                                    width: parent.width
                                    text: [CalendarEvents.when(row.modelData, root.day), row.modelData.location, row.modelData.calendarName].filter(Boolean).join(" · ")
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: actions
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 2

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: row.modelData.recurring
                                    text: Icons.repeat
                                    color: Theme.dim
                                    font.pixelSize: Theme.iconSizeSmall
                                }

                                // Read-only calendars, such as contact birthdays, are changed in Nextcloud.
                                IconButton {
                                    visible: !row.modelData.writable
                                    icon: Icons.openExternal
                                    iconColor: Theme.muted
                                    tooltip: I18n.t("calendar.editInNextcloud")
                                    onClicked: CalendarEvents.openInNextcloud()
                                }

                                IconButton {
                                    visible: row.modelData.writable
                                    icon: Icons.trash
                                    iconColor: Theme.muted
                                    tooltip: I18n.t("calendar.delete")
                                    onClicked: {
                                        root.confirmRow = row;
                                        root.confirming = row.rowKey;
                                    }
                                }
                            }
                        }

                        // Details beyond the line above: repetition and reminder, the description and the attendees.
                        Label {
                            width: parent.width
                            visible: row.open && text !== ""
                            topPadding: 2
                            text: [row.modelData.recurring ? I18n.t("calendar.repeats") : "", (row.modelData.alarms ?? []).length > 0 ? I18n.t("calendar.reminderSet") : ""].filter(Boolean).join(" · ")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width
                            visible: row.open
                            text: (row.modelData.description ?? "") !== "" ? row.modelData.description : I18n.t("calendar.noDescription")
                            color: (row.modelData.description ?? "") !== "" ? Theme.foreground : Theme.dim
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Repeater {
                            model: row.open ? row.modelData.attendees ?? [] : []

                            Label {
                                required property var modelData
                                width: rowContent.width
                                text: `${modelData.name || modelData.address} · ${I18n.t(`calendar.attendee.${modelData.status}`)}`
                                color: modelData.status === "accepted" ? Theme.accent : modelData.status === "declined" ? Theme.error : Theme.muted
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // The form replaces the list while an event is added.
    EventForm {
        id: form
        width: root.width
        visible: root.adding
        day: root.day
        maxFieldsHeight: root.maxListHeight
        onCancelled: root.adding = false
    }

    // A failed delete shows here, since the form may be closed.
    ErrorBanner {
        id: deleteError
        width: root.width
        visible: !root.adding && text !== ""
        text: CalendarEvents.error
    }
}
