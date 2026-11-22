import QtQuick
import qs.config
import qs.components
import qs.services

// Pointer speed for the mouse and the touchpad, then the touchpad's own settings when there is one.
Column {
    spacing: 2

    SectionTitle {
        text: I18n.t("pointer.speed")
    }

    // The slider runs from 0 to 1; the setting from -1 to 1, 0 being the default in the middle.
    SliderRow {
        width: parent.width
        icon: Icons.mouse
        title: I18n.t("pointer.speedTitle")
        value: (Input.pointerSpeed + 1) / 2
        valueText: Input.pointerSpeed === 0 ? I18n.t("pointer.default") : `${Input.pointerSpeed > 0 ? "+" : ""}${Math.round(Input.pointerSpeed * 100)}%`
        reserveTrailing: false
        onMoved: value => Input.setPointerSpeed(value * 2 - 1)
    }

    Column {
        width: parent.width
        spacing: 2
        visible: Input.touchpadPresent

        SectionTitle {
            text: I18n.t("touchpad.scrolling")
        }

        Repeater {
            model: ["natural", "traditional"]

            ListRow {
                required property string modelData

                width: parent.width
                text: I18n.t(`touchpad.${modelData}`)
                selected: Input.naturalScroll === (modelData === "natural")
                onClicked: Input.setNaturalScroll(modelData === "natural")
            }
        }

        SectionTitle {
            text: I18n.t("touchpad.tapping")
        }

        ItemRow {
            width: parent.width
            title: I18n.t("touchpad.tapToClick")
            onClicked: Input.setTapToClick(!Input.tapToClick)

            trailing: Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Input.tapToClick
                onToggled: Input.setTapToClick(!Input.tapToClick)
            }
        }
    }
}
