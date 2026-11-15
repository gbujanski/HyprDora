//@ pragma UseQApplication
//@ pragma IconTheme Papirus
import QtQuick
import Quickshell
import qs.modules.bar
import qs.modules.actioncenter
import qs.modules.notifications
import qs.modules.osd
import qs.modules.displays
import qs.modules.calendar
import qs.modules.battery
import qs.modules.capture
import qs.modules.media
import qs.modules.launcher
import qs.modules.lock
import qs.modules.restore
import qs.modules.polkit
import qs.modules.updates
import qs.services

ShellRoot {
    // The installed shell does not reload itself while a package update replaces its files one by one;
    // make install restarts it once instead. A shell run from the repository keeps reloading on save.
    Component.onCompleted: Quickshell.watchFiles = !Quickshell.shellDir.startsWith("/etc/")

    // Singletons are created on first use, and these have no UI that would use them.
    readonly property var wallpaper: Wallpaper
    readonly property var idle: Idle
    readonly property var automations: Automations
    readonly property var appearance: Appearance
    // Calendar reminders work without the calendar open.
    readonly property var calendarEvents: CalendarEvents

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    ActionCenter {}

    CalendarPanel {}

    Toasts {}

    NotificationPanel {}

    MediaPanel {}
    BatteryPanel {}
    LauncherPanel {}
    LockScreen {}
    SystemRestoreWindow {}
    PolkitDialog {}
    UpdatesPanel {}

    Osd {}

    DisplayConfirm {}

    BatteryWarning {}

    CaptureOverlay {}
}
