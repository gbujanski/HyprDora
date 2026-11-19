import QtQuick
import qs.components

// The display settings under the bar's display icon, shown while an external screen is connected: the same
// page as in the settings menu.
BarPanel {
    name: "displays"

    content: Component {
        DisplaysPage {}
    }
}
