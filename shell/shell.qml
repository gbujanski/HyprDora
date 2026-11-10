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
import qs.modules.capture
import qs.services

ShellRoot {
    // Singletons are created on first use, and these have no UI that would use them.
    readonly property var wallpaper: Wallpaper
    readonly property var idle: Idle

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

    CaptureOverlay {}
}
