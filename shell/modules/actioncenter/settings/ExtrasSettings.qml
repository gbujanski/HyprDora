import QtQuick
import qs.config
import qs.components
import qs.services

// Applications beyond the base system, in the window the welcome screen uses, which the action center would
// cover, so it closes first.
Column {
    spacing: 2

    ListRow {
        width: parent.width
        text: I18n.t("extras.open")
        onClicked: {
            Panels.close("actioncenter");
            Extras.open();
        }
    }
}
