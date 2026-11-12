import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// CPU, memory and battery. Statistics are read only while this view exists.
Column {
    id: root

    spacing: 0

    Component.onCompleted: SystemStats.acquire()
    Component.onDestruction: SystemStats.release()

    Item {
        width: parent.width
        height: 30

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "SYSTEM"
        }

        IconButton {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            icon: Icons.processes
            iconColor: Theme.muted
            tooltip: I18n.t("system.processes")
            onClicked: {
                SystemStats.openMonitor();
                Panels.closeActionCenter();
            }
        }
    }

    StatRow {
        width: parent.width
        icon: Icons.cpu
        title: I18n.t("system.cpu")
        value: Math.max(0, SystemStats.cpu)
        valueText: SystemStats.cpu < 0 ? "…" : `${Math.round(SystemStats.cpu * 100)}%`
    }

    StatRow {
        width: parent.width
        icon: Icons.memory
        title: I18n.t("system.memory")
        value: SystemStats.memory
        valueText: SystemStats.memTotal > 0 ? `${SystemStats.formatBytes(SystemStats.memUsed)} / ${SystemStats.formatBytes(SystemStats.memTotal)}` : "…"
        // Swap (zram on Fedora) only when in use.
        detail: SystemStats.swapUsed >= 64 * 1048576 ? `Swap: ${SystemStats.formatBytes(SystemStats.swapUsed)} / ${SystemStats.formatBytes(SystemStats.swapTotal)}` : ""
    }

    StatRow {
        width: parent.width
        visible: Power.hasBattery
        icon: Icons.battery(Power.level, !UPower.onBattery)
        title: I18n.t("system.battery")
        value: Power.level
        valueText: `${Math.round(Power.level * 100)}%`
        // Same thresholds as the bar and the warnings.
        fillColor: UPower.onBattery && Power.level <= Settings.batteryCritical ? Theme.error : UPower.onBattery && Power.level <= Settings.batteryLow ? Theme.warning : Theme.accent
        // Two short lines, so neither wraps mid-way: state with time, then clock, power and health.
        detail: Power.details === "" ? Power.summary : `${Power.summary}\n${Power.details}`
    }
}
