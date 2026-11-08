import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

BarButton {
    id: root

    required property ShellScreen screen

    readonly property bool open: Panels.calendarOpen && Panels.calendarScreen === screen

    // Minutowa dokładność: zegar nie budzi procesu co sekundę.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    label: clock.date.toLocaleString(Qt.locale(), "ddd d MMM   HH:mm")
    contentColor: open ? Theme.accent : Theme.foreground
    onClicked: Panels.toggleCalendar(root.screen)
}
