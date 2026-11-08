import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Hidden from the bar when there is no data.
BarButton {
    id: root

    required property ShellScreen screen

    visible: Weather.available
    icon: Weather.available ? Icons.weather(Weather.current.code, Weather.current.isDay) : ""
    label: Weather.available ? Weather.formatTemp(Weather.current.temp) : ""
    contentColor: Panels.calendarOpen && Panels.calendarScreen === screen ? Theme.accent : Theme.foreground
    tooltip: Weather.available
        ? I18n.t("weather.tooltip", { place: Settings.weatherPlace, description: Weather.describe(Weather.current.code), feels: Weather.formatTemp(Weather.current.feels) })
        : ""
    onClicked: Panels.toggleCalendar(root.screen)
}
