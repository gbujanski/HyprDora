import QtQuick
import qs.config
import qs.components
import qs.services

// The touchpad's scrolling direction.
Column {
    spacing: 2

    SectionTitle {
        text: I18n.t("touchpad.scrolling")
    }

    Repeater {
        model: ["natural", "traditional"]

        ListRow {
            required property string modelData

            width: parent.width
            text: I18n.t(`touchpad.${modelData}`)
            selected: Touchpad.naturalScroll === (modelData === "natural")
            onClicked: Touchpad.setNaturalScroll(modelData === "natural")
        }
    }
}
