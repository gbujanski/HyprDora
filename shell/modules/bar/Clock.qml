import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The weather, when there is data, and the date and time, as one button: both open the calendar panel,
// so they light up together.
BarButton {
    id: root

    required property ShellScreen screen

    readonly property bool open: Panels.isOpen("calendar") && Panels.currentScreen === screen

    // Minute precision, so the clock does not wake the process every second.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    icon: Weather.available ? Icons.weather(Weather.current.code, Weather.current.isDay) : ""
    label: Weather.available ? Weather.formatTemp(Weather.current.temp) : ""
    contentColor: open ? Theme.accent : Theme.foreground
    tooltip: Weather.available ? I18n.t("weather.tooltip", {
        place: Settings.weatherPlace,
        description: Weather.describe(Weather.current.code),
        feels: Weather.formatTemp(Weather.current.feels)
    }) : ""
    onClicked: Panels.toggle("calendar", root.screen)

    Label {
        anchors.verticalCenter: parent.verticalCenter
        // A wider gap after the temperature than between the icon and the temperature.
        leftPadding: Weather.available ? 8 : 0
        text: clock.date.toLocaleString(I18n.locale, "ddd d MMM   HH:mm")
        color: root.contentColor
    }
}
