//@ pragma UseQApplication
//@ pragma IconTheme Papirus
import Quickshell
import qs.modules.bar
import qs.modules.actioncenter
import qs.modules.notifications
import qs.modules.osd
import qs.modules.displays
import qs.modules.calendar
import qs.modules.battery
import qs.services

ShellRoot {
    // Singletons are created on first use, and this one has no UI that would use it.
    readonly property var wallpaper: Wallpaper

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    ActionCenter {}

    CalendarPanel {}

    Toasts {}

    Osd {}

    DisplayConfirm {}

    BatteryWarning {}
}
