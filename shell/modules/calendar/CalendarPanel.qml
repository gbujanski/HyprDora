import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The calendar with the weather, under the clock: the month and the weather on the left, the selected day's
// events on the right.
BarPanel {
    id: frame

    // The two columns, and the line between them with its margins.
    readonly property int columnWidth: 320 - 2 * Theme.panelPadding
    readonly property int columnGap: 2 * Theme.panelPadding + 1

    name: "calendar"
    side: "center"
    panelWidth: 2 * columnWidth + columnGap + 2 * padding

    onOpenChanged: {
        if (open) {
            Weather.refreshIfStale();
            CalendarEvents.refresh();
        }
    }

    content: Component {
        Item {
            id: panel

            readonly property int columnWidth: frame.columnWidth
            implicitHeight: content.implicitHeight
            focus: true

            property int year: clock.date.getFullYear()
            property int month: clock.date.getMonth()
            readonly property bool isCurrentMonth: year === clock.date.getFullYear() && month === clock.date.getMonth()

            function shiftMonth(delta) {
                const d = new Date(year, month + delta, 1);
                year = d.getFullYear();
                month = d.getMonth();
            }

            function showToday() {
                year = clock.date.getFullYear();
                month = clock.date.getMonth();
                grid.selectedDay = new Date(clock.date);
            }

            Component.onCompleted: {
                // Breaks the bindings: from here on only the buttons drive it.
                year = clock.date.getFullYear();
                month = clock.date.getMonth();
                forceActiveFocus();
            }

            // Esc first closes the delete question, then, left to the frame, the calendar.
            Keys.onEscapePressed: event => {
                if (dayEvents.confirming !== "")
                    dayEvents.confirming = "";
                else
                    event.accepted = false;
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp)
                    panel.shiftMonth(-1);
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown)
                    panel.shiftMonth(1);
                else if (event.key === Qt.Key_Home)
                    panel.showToday();
                else
                    return;
                event.accepted = true;
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            // The wheel over the month changes it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                // A touchpad sends dozens of events per gesture, so month changes have a minimum delay.
                // Longer scrolling moves through months at a pace that can be followed.
                property real lastStep: 0

                onWheel: wheel => {
                    // Months change only over the month heading and grid; elsewhere the wheel goes on,
                    // such as to a long list of events.
                    const corner = monthHeader.mapToItem(this, 0, 0);
                    const bottom = grid.mapToItem(this, 0, grid.height).y;
                    if (wheel.y < corner.y || wheel.y > bottom || wheel.x < corner.x || wheel.x > corner.x + grid.width) {
                        wheel.accepted = false;
                        return;
                    }
                    const delta = wheel.angleDelta.y;
                    if (delta === 0)
                        return;
                    const now = Date.now();
                    if (now - lastStep < Settings.calendarScrollDelay)
                        return;
                    lastStep = now;
                    panel.shiftMonth(delta > 0 ? -1 : 1);
                }
            }

            Row {
                id: content

                anchors {
                    top: parent.top
                    left: parent.left
                }
                spacing: Theme.panelPadding

                Column {
                    id: leftColumn
                    width: panel.columnWidth
                    spacing: 10

                    Column {
                        id: dateHeader
                        spacing: 1

                        Label {
                            text: clock.date.toLocaleDateString(I18n.locale, "dddd")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            text: clock.date.toLocaleDateString(I18n.locale, "d MMMM yyyy")
                            font.pixelSize: Theme.fontSizeTitle + 3
                            font.weight: Font.DemiBold
                        }
                    }

                    Item {
                        id: monthHeader
                        width: parent.width
                        height: 30

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 4
                            text: `${I18n.monthName(panel.month)} ${panel.year}`
                            font.weight: Font.Medium
                        }

                        Row {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !panel.isCurrentMonth
                                implicitHeight: 26
                                text: I18n.t("calendar.today")
                                onClicked: panel.showToday()
                            }

                            IconButton {
                                icon: Icons.chevronLeft
                                iconColor: Theme.muted
                                tooltip: I18n.t("calendar.previousMonth")
                                onClicked: panel.shiftMonth(-1)
                            }

                            IconButton {
                                icon: Icons.chevronRight
                                iconColor: Theme.muted
                                tooltip: I18n.t("calendar.nextMonth")
                                onClicked: panel.shiftMonth(1)
                            }
                        }
                    }

                    MonthGrid {
                        id: grid
                        width: parent.width
                        year: panel.year
                        month: panel.month
                        today: clock.date
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        visible: weather.visible
                        color: Theme.surface
                    }

                    WeatherDetails {
                        id: weather
                        width: parent.width
                        visible: Settings.hasWeatherLocation
                    }
                }

                Rectangle {
                    width: 1
                    height: leftColumn.height
                    color: Theme.surface
                }

                // As tall as the left column at most: a long list of events, or the form for a new one,
                // scrolls rather than lengthening the panel.
                DayEvents {
                    id: dayEvents
                    width: panel.columnWidth
                    day: grid.selectedDay
                    today: clock.date
                    maxListHeight: Math.max(80, leftColumn.height - chromeHeight - spacing)
                }
            }

            // While the delete question shows, a click anywhere on the calendar closes just the question.
            MouseArea {
                anchors.fill: parent
                visible: dayEvents.confirming !== ""
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: dayEvents.confirming = ""
                onWheel: wheel => wheel.accepted = true
            }

            // The delete question, beside the panel at the height of its event, so the list neither grows nor
            // scrolls. It goes to the right, beside the events column, or to the left where the right has no room.
            // It sits on the window rather than in the panel, so it can stand outside it.
            Rectangle {
                id: question

                parent: frame.window?.contentItem ?? panel

                readonly property var event: dayEvents.confirmEvent
                readonly property real rowY: {
                    const row = dayEvents.confirmRow;
                    // Read again when the list scrolls or the panel moves.
                    void frame.panel?.y;
                    return row && event && frame.window ? row.mapToItem(frame.window.contentItem, 0, 0).y : 0;
                }

                visible: event !== null && frame.shown
                width: 260
                height: questionContent.implicitHeight + 2 * Theme.panelPadding
                // On a narrow screen with room on neither side, it stays on the screen over the panel's edge.
                x: {
                    if (!frame.panel || !frame.window)
                        return 0;
                    const left = frame.panel.x - width - 8;
                    const right = frame.panel.x + frame.panel.width + 8;
                    if (right + width <= frame.window.width - Theme.panelMargin)
                        return right;
                    return Math.max(Theme.panelMargin, Math.min(left, frame.window.width - width - Theme.panelMargin));
                }
                y: frame.window ? Math.max(Theme.panelMargin, Math.min(rowY, frame.window.height - height - Theme.panelMargin)) : 0
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface

                // Clicks on the question stay on it.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                }

                Column {
                    id: questionContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.panelPadding
                    }
                    spacing: 8

                    Label {
                        width: parent.width
                        text: question.event?.recurring ? I18n.t("calendar.deleteRepeating") : I18n.t("calendar.deleteQuestion", {
                            summary: question.event?.summary ?? ""
                        })
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                    }

                    TextButton {
                        width: parent.width
                        primary: true
                        text: question.event?.recurring ? I18n.t("calendar.deleteSeries") : I18n.t("calendar.delete")
                        active: CalendarEvents.busy === ""
                        onClicked: CalendarEvents.remove(question.event, true)
                    }

                    TextButton {
                        width: parent.width
                        visible: (question.event?.recurring ?? false) && (question.event?.occurrence ?? "") !== ""
                        text: I18n.t("calendar.deleteOccurrence")
                        active: CalendarEvents.busy === ""
                        onClicked: CalendarEvents.remove(question.event, false)
                    }

                    Item {
                        width: parent.width
                        height: cancelButton.height

                        Spinner {
                            anchors.verticalCenter: parent.verticalCenter
                            running: CalendarEvents.busy === "delete"
                        }

                        TextButton {
                            id: cancelButton
                            anchors.right: parent.right
                            text: I18n.t("common.cancel")
                            onClicked: dayEvents.confirming = ""
                        }
                    }
                }
            }
        }
    }
}
