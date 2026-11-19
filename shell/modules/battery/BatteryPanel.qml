import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Battery state and power profiles under the battery icon, and under the power profile icon. Without a
// battery, as on a desktop, it holds the profiles alone.
BarPanel {
    name: "battery"

    content: Component {
        Column {
            id: content

            spacing: 12

            Row {
                width: parent.width
                visible: Power.hasBattery
                spacing: 12

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.battery(Power.level, !UPower.onBattery)
                    font.pixelSize: Theme.iconSizeHero
                    color: UPower.onBattery && Power.level <= Settings.batteryCritical ? Theme.error : UPower.onBattery && Power.level <= Settings.batteryLow ? Theme.warning : Theme.foreground
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46
                    spacing: 2

                    Label {
                        text: `${Math.round(Power.level * 100)}%`
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.DemiBold
                    }

                    Label {
                        width: parent.width
                        text: Power.summary
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: Power.details
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }

            SegmentedControl {
                width: parent.width
                currentValue: Power.profile
                options: [
                    {
                        value: PowerProfile.PowerSaver,
                        label: I18n.t("power.saver"),
                        icon: Icons.powerSaver
                    },
                    {
                        value: PowerProfile.Balanced,
                        label: I18n.t("power.balanced"),
                        icon: Icons.balanced
                    },
                    {
                        value: PowerProfile.Performance,
                        label: I18n.t("power.performance"),
                        icon: Icons.performance,
                        enabled: Power.hasPerformance
                    }
                ]
                onSelected: value => Power.setProfile(value)
            }
        }
    }
}
