//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.modules.bar
import qs.modules.actioncenter
import qs.modules.actioncenter.pages
import qs.modules.notifications
import qs.modules.osd
import qs.modules.displays
import qs.modules.calendar
import qs.modules.battery
import qs.modules.audio
import qs.modules.drives
import qs.modules.capture
import qs.modules.media
import qs.modules.launcher
import qs.modules.lock
import qs.modules.restore
import qs.modules.polkit
import qs.modules.updates
import qs.modules.overview
import qs.services

ShellRoot {
    // The installed shell does not reload itself while a package update replaces its files one by one;
    // make install restarts it once instead. A shell run from the repository keeps reloading on save.
    Component.onCompleted: Quickshell.watchFiles = !Quickshell.shellDir.startsWith("/etc/")

    // Singletons are created on first use, and these have no UI that would use them.
    readonly property var wallpaper: Wallpaper
    readonly property var idle: Idle
    // The brightness and volume keys call these over IPC, which exists only once they are created.
    readonly property var brightness: Brightness
    readonly property var audio: Audio
    readonly property var automations: Automations
    readonly property var appearance: Appearance
    readonly property var backgroundApps: BackgroundApps
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
    SoundPanel {}

    // Wi-Fi, Bluetooth and VPN under their bar icons: the action center's own pages.
    PagePanel {
        name: "wifi"
        page: Component {
            WifiPage {}
        }
    }

    PagePanel {
        name: "bluetooth"
        page: Component {
            BluetoothPage {}
        }
    }

    PagePanel {
        name: "vpn"
        page: Component {
            VpnPage {}
        }
    }
    DrivesPanel {}
    LauncherPanel {}
    LockScreen {}
    SystemRestoreWindow {}
    PolkitDialog {}
    UpdatesPanel {}
    UpdateScreen {}
    Overview {}

    Osd {}

    DisplayConfirm {}
    DisplaysPanel {}

    BatteryWarning {}

    CaptureOverlay {}
}
