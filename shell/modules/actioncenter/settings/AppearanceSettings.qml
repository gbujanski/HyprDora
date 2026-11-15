import QtQuick
import qs.config
import qs.components

// Dark or light theme for the shell and GTK applications, and the icon theme.
Column {
    spacing: 2

    SectionTitle {
        text: I18n.t("appearance.theme")
    }

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

    SectionTitle {
        topPadding: 8
        text: I18n.t("appearance.icons")
    }

    Repeater {
        model: Settings.iconThemes

        ListRow {
            required property string modelData

            width: parent.width
            text: modelData
            selected: Settings.iconTheme === modelData
            onClicked: Settings.set("iconTheme", modelData === "Papirus" ? undefined : modelData)
        }
    }
}
