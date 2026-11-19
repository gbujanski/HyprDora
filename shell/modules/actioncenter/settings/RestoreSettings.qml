import QtQuick
import qs.config
import qs.components
import qs.services

// Restoring the system from a snapshot, and taking one now. Both ask for the administrator password in a
// window of their own, which the action center would cover, so it closes first.
Column {
    spacing: 2

    ListRow {
        width: parent.width
        text: I18n.t("restore.restoreFrom")
        onClicked: {
            Panels.closeActionCenter();
            SystemRestore.open();
        }
    }

    ListRow {
        width: parent.width
        text: I18n.t("restore.create")
        onClicked: {
            Panels.closeActionCenter();
            SystemRestore.create();
        }
    }
}
