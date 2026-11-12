import QtQuick
import qs.config
import qs.components
import qs.services

// Automations: a switch for each, with its options shown while it is on. Times change by 30 minutes with
// the arrows or the wheel; days toggle with a click.
Column {
    id: root

    // The settings menu, which shows the choice of VPN connection.
    property Item menu: null

    readonly property var dayKeys: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    spacing: 4

    Component.onCompleted: Automations.refreshNetworks()

    // Title row with a switch.
    component Toggle: Item {
        id: toggle

        property string title
        property string name
        readonly property bool on: Automations.rule(name).enabled

        width: root.width
        height: 34

        Label {
            anchors {
                left: parent.left
                right: toggleSwitch.left
                leftMargin: 8
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: toggle.title
            elide: Text.ElideRight
        }

        Switch {
            id: toggleSwitch
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            checked: toggle.on
            onToggled: Automations.update(toggle.name, {
                enabled: !toggle.on
            })
        }
    }

    // A time that the arrows or the wheel move by 30 minutes.
    component TimeField: Row {
        id: field

        property string label
        property string name
        property string key
        readonly property int minutes: Automations.rule(name)[key]

        /**
         * Moves the time, wrapping around midnight.
         * @param {int} steps  half hours, negative for earlier
         */
        function move(steps) {
            Automations.update(name, {
                [key]: ((minutes + steps * 30) % 1440 + 1440) % 1440
            });
        }

        spacing: 2

        Label {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 4
            text: field.label
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.chevronLeft
            iconColor: Theme.muted
            onClicked: field.move(-1)
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            horizontalAlignment: Text.AlignHCenter
            text: Automations.clock(field.minutes)
            font.weight: Font.Medium

            MouseArea {
                anchors.fill: parent
                onWheel: wheel => field.move(wheel.angleDelta.y > 0 ? 1 : -1)
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.chevronRight
            iconColor: Theme.muted
            onClicked: field.move(1)
        }
    }

    // Hours and days of a schedule.
    component Schedule: Column {
        id: schedule

        property string name
        readonly property var days: Automations.rule(name).days ?? []

        width: root.width
        leftPadding: 8
        bottomPadding: 6
        spacing: 4

        Row {
            spacing: 14

            TimeField {
                label: I18n.t("automations.from")
                name: schedule.name
                key: "from"
            }

            TimeField {
                label: I18n.t("automations.to")
                name: schedule.name
                key: "to"
            }
        }

        Row {
            spacing: 4

            Repeater {
                model: 7

                Rectangle {
                    id: day

                    required property int index
                    readonly property int number: index + 1
                    readonly property bool chosen: schedule.days.includes(number)

                    width: 36
                    height: 26
                    radius: Theme.radius
                    color: chosen ? Theme.accent : dayArea.containsMouse ? Theme.surfaceHover : Theme.surface

                    Label {
                        anchors.centerIn: parent
                        text: I18n.t(`automations.day.${root.dayKeys[day.index]}`)
                        color: day.chosen ? Theme.accentText : Theme.foreground
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: day.chosen ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Automations.update(schedule.name, {
                            days: day.chosen ? schedule.days.filter(d => d !== day.number) : [...schedule.days, day.number].sort()
                        })
                    }
                }
            }
        }
    }

    Repeater {
        model: [
            {
                name: "dnd",
                title: I18n.t("automations.dnd")
            },
            {
                name: "coffee",
                title: I18n.t("automations.coffee")
            },
            {
                name: "mute",
                title: I18n.t("automations.mute")
            }
        ]

        Column {
            required property var modelData

            width: root.width

            Toggle {
                name: parent.modelData.name
                title: parent.modelData.title
            }

            Schedule {
                visible: Automations.rule(parent.modelData.name).enabled
                name: parent.modelData.name
            }
        }
    }

    Toggle {
        name: "headphones"
        title: I18n.t("automations.headphones")
    }

    // Only with a VPN to connect.
    Column {
        id: vpnRule

        readonly property var r: Automations.rule("vpn")
        readonly property var target: Vpn.connections.find(c => c.uuid === r.connection) ?? Vpn.connections[0] ?? null

        width: root.width
        visible: Vpn.connections.length > 0

        Toggle {
            name: "vpn"
            title: I18n.t("automations.vpn")
        }

        Column {
            width: parent.width
            visible: vpnRule.r.enabled
            leftPadding: 8
            bottomPadding: 6
            spacing: 2

            // The VPN to connect; with more than one, hovering opens the choice.
            Rectangle {
                id: connectionRow

                readonly property bool open: root.menu?.submenu?.owner === connectionRow

                /** Shows the VPN connections beside the row. */
                function showOptions() {
                    if (Vpn.connections.length < 2)
                        return;
                    root.menu?.openSubmenu(connectionRow, Vpn.connections.map(c => ({
                                value: c.uuid,
                                label: c.name
                            })), vpnRule.target?.uuid, uuid => Automations.update("vpn", {
                            connection: uuid
                        }));
                }

                width: parent.width - 8
                height: 30
                radius: Theme.radius
                color: open || connectionArea.containsMouse ? Theme.surface : "transparent"

                Label {
                    anchors {
                        left: parent.left
                        leftMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    text: I18n.t("automations.vpnConnection")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 4

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: vpnRule.target?.name ?? ""
                        font.weight: Font.Medium
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Vpn.connections.length > 1
                        text: Icons.chevronRight
                        color: Theme.muted
                    }
                }

                MouseArea {
                    id: connectionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: {
                        if (containsMouse)
                            connectionRow.showOptions();
                    }
                }
            }

            Label {
                leftPadding: 6
                topPadding: 4
                bottomPadding: 2
                text: I18n.t("automations.vpnHome")
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: Automations.savedNetworks

                ListRow {
                    required property var modelData
                    readonly property var home: vpnRule.r.homeNetworks ?? []

                    width: vpnRule.width - 8
                    text: modelData.name
                    selected: home.includes(modelData.ssid)
                    onClicked: Automations.update("vpn", {
                        homeNetworks: selected ? home.filter(s => s !== modelData.ssid) : [...home, modelData.ssid]
                    })
                }
            }
        }
    }
}
