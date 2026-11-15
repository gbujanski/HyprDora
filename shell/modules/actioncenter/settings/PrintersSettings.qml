import QtQuick
import qs.config
import qs.components
import qs.services

// Printers and scanners: the added printers, with removing and choosing the default, the network printers
// found and not added, with "+", and the scanners found, which need no adding. Opening it searches again.
Column {
    id: root

    spacing: 4

    Component.onCompleted: Printers.refresh()

    // One printer or scanner: an icon, its name and state, and buttons on the right.
    component Device: Rectangle {
        id: device

        property string icon
        property string title
        property string detail
        property bool highlighted: false
        default property alias actions: actionRow.data

        width: root.width
        height: 40
        radius: Theme.radius
        color: area.containsMouse ? Theme.surface : "transparent"

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
        }

        Icon {
            id: deviceIcon
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: device.icon
            color: device.highlighted ? Theme.accent : Theme.muted
        }

        Column {
            anchors {
                left: deviceIcon.right
                right: actionRow.left
                leftMargin: 10
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }

            Label {
                width: parent.width
                text: device.title
                elide: Text.ElideRight
            }

            Label {
                width: parent.width
                visible: text !== ""
                text: device.detail
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        Row {
            id: actionRow
            anchors {
                right: parent.right
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            spacing: 2
        }
    }

    Item {
        width: root.width
        height: 24

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("printers.printers")
        }

        Spinner {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            running: Printers.searching
        }
    }

    Repeater {
        model: Printers.printers

        Device {
            required property var modelData

            icon: Icons.printer
            title: modelData.name.replace(/_/g, " ")
            detail: [modelData.isDefault ? I18n.t("printers.default") : "", I18n.t(`printers.state.${modelData.state}`)].filter(Boolean).join(" · ")
            highlighted: modelData.isDefault

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: Printers.busy === parent.parent.modelData?.name
            }

            IconButton {
                visible: !parent.parent.modelData?.isDefault
                icon: Icons.star
                iconColor: Theme.muted
                tooltip: I18n.t("printers.setDefault")
                onClicked: Printers.setDefault(parent.parent.modelData)
            }

            IconButton {
                icon: Icons.trash
                iconColor: Theme.muted
                tooltip: I18n.t("printers.remove")
                onClicked: Printers.remove(parent.parent.modelData)
            }
        }
    }

    Repeater {
        model: Printers.found

        Device {
            required property var modelData

            icon: Icons.printer
            title: modelData.name
            detail: I18n.t("printers.foundOnNetwork")

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: Printers.busy === parent.parent.modelData?.name
            }

            IconButton {
                icon: Icons.plus
                iconColor: Theme.accent
                tooltip: I18n.t("printers.add")
                onClicked: Printers.add(parent.parent.modelData)
            }
        }
    }

    Label {
        visible: Printers.printers.length === 0 && Printers.found.length === 0 && !Printers.searching
        leftPadding: 8
        text: I18n.t("printers.none")
        color: Theme.muted
    }

    ErrorBanner {
        width: root.width
        text: Printers.error
    }

    SectionTitle {
        topPadding: 6
        text: I18n.t("printers.scanners")
    }

    Repeater {
        model: Printers.scanners

        Device {
            required property var modelData

            icon: Icons.scanner
            title: modelData.name

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("printers.scan")
                onClicked: {
                    Panels.closeActionCenter();
                    Printers.scan();
                }
            }
        }
    }

    Label {
        visible: Printers.scanners.length === 0 && !Printers.searching
        leftPadding: 8
        text: I18n.t("printers.noScanners")
        color: Theme.muted
    }

    TextButton {
        anchors.right: parent.right
        text: I18n.t("printers.more")
        onClicked: {
            Panels.closeActionCenter();
            Printers.openSettings();
        }
    }
}
