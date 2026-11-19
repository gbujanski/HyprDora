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

        ItemRow {
            id: printer

            required property var modelData

            width: root.width
            icon: Icons.printer
            iconColor: modelData.isDefault ? Theme.accent : Theme.muted
            title: modelData.name.replace(/_/g, " ")
            subtitle: [modelData.isDefault ? I18n.t("printers.default") : "", I18n.t(`printers.state.${modelData.state}`)].filter(Boolean).join(" · ")
            interactive: false

            trailing: [
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: Printers.busy === printer.modelData.name
                },
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !printer.modelData.isDefault
                    icon: Icons.star
                    iconColor: Theme.muted
                    tooltip: I18n.t("printers.setDefault")
                    onClicked: Printers.setDefault(printer.modelData)
                },
                DeleteButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: I18n.t("printers.remove")
                    onConfirmed: Printers.remove(printer.modelData)
                }
            ]
        }
    }

    Repeater {
        model: Printers.found

        ItemRow {
            id: found

            required property var modelData

            width: root.width
            icon: Icons.printer
            iconColor: Theme.muted
            title: modelData.name
            subtitle: I18n.t("printers.foundOnNetwork")
            interactive: false

            trailing: [
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: Printers.busy === found.modelData.name
                },
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.plus
                    iconColor: Theme.accent
                    tooltip: I18n.t("printers.add")
                    onClicked: Printers.add(found.modelData)
                }
            ]
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

        ItemRow {
            required property var modelData

            width: root.width
            icon: Icons.scanner
            iconColor: Theme.muted
            title: modelData.name
            interactive: false

            trailing: TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("printers.scan")
                onClicked: {
                    Panels.close("actioncenter");
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
            Panels.close("actioncenter");
            Printers.openSettings();
        }
    }
}
