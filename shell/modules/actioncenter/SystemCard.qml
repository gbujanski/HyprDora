import QtQuick
import qs.config
import qs.components
import qs.services

// CPU, pamięć i bateria. Statystyki są odczytywane tylko, dopóki ten widok istnieje.
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
            tooltip: "Procesy (btop)"
            onClicked: {
                SystemStats.openMonitor();
                Panels.closeActionCenter();
            }
        }
    }

    StatRow {
        width: parent.width
        icon: Icons.cpu
        title: "Procesor"
        value: Math.max(0, SystemStats.cpu)
        valueText: SystemStats.cpu < 0 ? "…" : `${Math.round(SystemStats.cpu * 100)}%`
    }

    StatRow {
        width: parent.width
        icon: Icons.memory
        title: "Pamięć"
        value: SystemStats.memory
        valueText: SystemStats.memTotal > 0
            ? `${SystemStats.formatBytes(SystemStats.memUsed)} / ${SystemStats.formatBytes(SystemStats.memTotal)}`
            : "…"
        // Swap (na Fedorze zram) tylko wtedy, gdy jest używany.
        detail: SystemStats.swapUsed >= 64 * 1048576
            ? `Swap: ${SystemStats.formatBytes(SystemStats.swapUsed)} / ${SystemStats.formatBytes(SystemStats.swapTotal)}`
            : ""
    }

    StatRow {
        width: parent.width
        visible: Power.hasBattery
        icon: Icons.battery(Power.level, Power.charging)
        title: "Bateria"
        value: Power.level
        valueText: `${Math.round(Power.level * 100)}%`
        // Te same progi co na pasku.
        fillColor: Power.charging || Power.full ? Theme.accent
            : Power.level <= 0.15 ? Theme.error
            : Power.level <= 0.30 ? Theme.warning
            : Theme.accent
        // Dwa krótkie wiersze, żeby żaden nie łamał się w połowie:
        // stan z czasem oraz godzina, moc i kondycja.
        detail: {
            const known = !Power.full && Power.secondsLeft > 0;
            const first = Power.stateText + (!known ? ""
                : Power.charging ? ` · do pełna ${Power.formatTime(Power.secondsLeft)}`
                : ` · zostało ${Power.formatTime(Power.secondsLeft)}`);
            const second = [];
            if (known) second.push(`${Power.charging ? "Pełna" : "Do"} ok. ${Power.endClock(Power.secondsLeft)}`);
            if (Power.rate > 0.05) second.push(`${Power.charging ? "moc" : "pobór"} ${Power.rate.toFixed(1).replace(".", ",")} W`);
            if (Power.health > 0) second.push(`kondycja ${Math.round(Power.health * 100)}%`);
            if (second.length === 0) return first;
            const rest = second.join(" · ");
            return `${first}\n${rest[0].toUpperCase()}${rest.slice(1)}`;
        }
    }
}
