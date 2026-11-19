import QtQuick
import qs.config
import qs.components
import qs.services

// One Bluetooth device: a click connects or disconnects it, the bin removes a paired one.
ItemRow {
    id: root

    required property var device

    icon: Icons.bluetoothDevice(device.icon)
    title: device.name
    subtitle: Bluetooth.statusText(device)
    highlighted: device.connected
    onClicked: Bluetooth.activate(device)

    trailing: DeleteButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.device.paired
        label: I18n.t("bluetooth.forget")
        onConfirmed: Bluetooth.forget(root.device)
    }
}
