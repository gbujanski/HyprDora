import QtQuick
import qs.components

// The sound controls under the bar's sound icon, the same as in the action center, with both sections
// unfolded.
BarPanel {
    name: "sound"

    content: Component {
        SoundControls {
            expanded: true
        }
    }
}
