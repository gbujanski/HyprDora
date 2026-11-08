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

ShellRoot {
    // Osobny pasek na każdym monitorze; Variants sam tworzy i usuwa instancje
    // przy podłączaniu oraz odłączaniu ekranów.
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
