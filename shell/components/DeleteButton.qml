import QtQuick
import qs.config

// A bin that asks for a second click: the first turns it red and says so, the second deletes. Without the
// second, it calms down after a few seconds.
IconButton {
    id: root

    // What it does, such as "Forget the network".
    property string label: ""
    property bool armed: false

    signal confirmed

    icon: Icons.trash
    iconColor: armed ? Theme.error : Theme.muted
    tooltip: armed ? I18n.t("common.clickAgain") : label
    onClicked: {
        if (armed) {
            armed = false;
            confirmed();
        } else {
            armed = true;
            disarm.restart();
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }
}
