import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Calendar with weather below the clock. Like the action center, a click outside
// or Esc closes it, and a closed window does not exist.
Scope {
    id: root

    Connections {
        target: Panels
        function onCalendarOpenChanged() {
            if (Panels.calendarOpen) {
                Weather.refreshIfStale();
                CalendarEvents.refresh();
            } else {
                closeDelay.restart();
            }
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.calendarOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.calendarOpen

            Component.onCompleted: entered = true

            screen: Panels.calendarScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-calendar"
            // OnDemand, not Exclusive: with Exclusive, Hyprland routes all clicks to this layer
            // and the bar stops reacting. Focus still reaches the panel on open, so Esc works.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeCalendar()
            }

            Rectangle {
                id: panel

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

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: Theme.panelMargin
                }
                width: 320
                height: content.implicitHeight + Theme.panelPadding * 2
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                transform: Translate {
                    y: window.shown ? 0 : -12
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.animPanel
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animPanel
                    }
                }

                // Esc first closes the delete question, then the calendar.
                Keys.onEscapePressed: {
                    if (dayEvents.confirming !== "")
                        dayEvents.confirming = "";
                    else
                        Panels.closeCalendar();
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

                // Absorbs clicks so they do not reach the closing area.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    // A touchpad sends dozens of events per gesture, so month changes have a minimum delay.
                    // Longer scrolling moves through months at a pace that can be followed.
                    property real lastStep: 0

                    onWheel: wheel => {
                        // Months change only over the month heading and grid; elsewhere the wheel goes on,
                        // such as to a long list of events.
                        const top = monthHeader.mapToItem(this, 0, 0).y;
                        const bottom = grid.mapToItem(this, 0, grid.height).y;
                        if (wheel.y < top || wheel.y > bottom) {
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

                Column {
                    id: content

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
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
                        visible: dayEvents.visible
                        color: Theme.surface
                    }

                    DayEvents {
                        id: dayEvents
                        width: parent.width
                        visible: CalendarEvents.enabled
                        day: grid.selectedDay
                        // The rest of the panel stays whole on the screen; the list of events scrolls.
                        maxListHeight: Math.max(120, window.height - 2 * Theme.panelMargin - 2 * Theme.panelPadding - dateHeader.height - monthHeader.height - grid.height - 1 - chromeHeight - (weatherSeparator.visible ? 1 : 0) - (weather.visible ? weather.height : 0) - content.spacing * 6)
                    }

                    Rectangle {
                        id: weatherSeparator
                        width: parent.width
                        height: 1
                        visible: weather.visible
                        color: Theme.surface
                    }

                    // Hidden while an event is added, so the form has room.
                    WeatherDetails {
                        id: weather
                        width: parent.width
                        visible: Settings.hasWeatherLocation && !dayEvents.adding
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
            }

            // The delete question, beside the panel at the height of its event, so the list neither grows nor
            // scrolls. It goes to the left, or to the right where the left has no room.
            Rectangle {
                id: question

                readonly property var event: dayEvents.confirmEvent
                readonly property real rowY: {
                    const row = dayEvents.confirmRow;
                    // Read again when the list scrolls or the panel moves.
                    void panel.y;
                    return row && event ? row.mapToItem(window.contentItem, 0, 0).y : 0;
                }

                visible: event !== null && window.shown
                width: 260
                height: questionContent.implicitHeight + 2 * Theme.panelPadding
                // On a narrow screen with room on neither side, it stays on the screen over the panel's edge.
                x: {
                    const left = panel.x - width - 8;
                    const right = panel.x + panel.width + 8;
                    if (left >= Theme.panelMargin)
                        return left;
                    return Math.max(Theme.panelMargin, Math.min(right, window.width - width - Theme.panelMargin));
                }
                y: Math.max(Theme.panelMargin, Math.min(rowY, window.height - height - Theme.panelMargin))
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
