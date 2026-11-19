import QtQuick
import qs.components
import qs.services

// Player controls under the media button next to the clock.
BarPanel {
    name: "media"
    side: "center"

    content: Component {
        MediaCard {}
    }

    // The panel has nothing to show once the last player is gone.
    Connections {
        target: Media
        function onHasPlayerChanged() {
            if (!Media.hasPlayer)
                Panels.close("media");
        }
    }
}
