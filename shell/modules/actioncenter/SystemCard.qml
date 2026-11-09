import QtQuick
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
        icon: Icons.battery(Power.level, Power.charging)
        title: I18n.t("system.battery")
        value: Power.level
        valueText: `${Math.round(Power.level * 100)}%`
        // Same thresholds as the bar.
        fillColor: Power.charging || Power.full ? Theme.accent : Power.level <= 0.15 ? Theme.error : Power.level <= 0.30 ? Theme.warning : Theme.accent
        // Two short lines, so neither wraps mid-way: state with time, then clock, power and health.
        detail: {
            const known = !Power.full && Power.secondsLeft > 0;
            const first = Power.stateText + (!known ? "" : Power.charging ? " · " + I18n.t("battery.untilFull", {
                    time: Power.formatTime(Power.secondsLeft)
                }) : " · " + I18n.t("battery.remaining", {
                    time: Power.formatTime(Power.secondsLeft)
                }));
            const second = [];
            if (known)
                second.push(I18n.t(Power.charging ? "battery.fullAt" : "battery.emptyAt", {
                    time: Power.endClock(Power.secondsLeft)
                }));
            if (Power.rate > 0.05)
                second.push(I18n.t(Power.charging ? "battery.chargeRate" : "battery.drawRate", {
                    watts: Power.rate.toLocaleString(I18n.locale, "f", 1)
                }));
            if (Power.health > 0)
                second.push(I18n.t("battery.health", {
                    percent: Math.round(Power.health * 100)
                }));
            if (second.length === 0)
                return first;
            const rest = second.join(" · ");
            return `${first}\n${rest[0].toUpperCase()}${rest.slice(1)}`;
        }
    }
}
