import QtQuick
import qs.config
import qs.components

// Dark or light theme for the shell and GTK applications.
Column {
    spacing: 2

    Repeater {
        model: ["dark", "light"]

        ListRow {
            required property string modelData

            width: parent.width
            text: I18n.t(`appearance.${modelData}`)
            selected: Settings.theme === modelData
            onClicked: Settings.set("theme", modelData === "dark" ? undefined : modelData)
        }
    }
}
