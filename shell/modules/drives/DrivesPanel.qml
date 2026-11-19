import QtQuick
import Quickshell
import qs.components
import qs.services

// Removable drives under the bar's drive icon, each with its partitions and a button that removes it safely.
BarPanel {
    name: "drives"

    content: Component {
        Column {
            spacing: 4

            Repeater {
                model: ScriptModel {
                    values: Drives.drives
                    objectProp: "id"
                }

                DriveRow {
                    width: parent.width
                }
            }
        }
    }

    // Nothing left to show once the last drive is gone.
    Connections {
        target: Drives
        function onDrivesChanged() {
            if (Drives.drives.length === 0)
                Panels.close("drives");
        }
    }
}
