import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: page

    // ActionCenter gives this page focus because it handles the keyboard.
    readonly property bool wantsFocus: true

    spacing: 2

    Component.onCompleted: Session.resetSelection()
    Component.onDestruction: Session.cancelConfirm()

    // Outside a confirmation, Esc is not handled here, so it reaches the panel and returns to the main view.
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            if (!Session.confirmAction) return;
            Session.cancelConfirm();
            break;
        case Qt.Key_Up:
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            Session.move(-1);
            break;
        case Qt.Key_Down:
        case Qt.Key_Right:
        case Qt.Key_Tab:
            Session.move(1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            Session.activate();
            break;
        default:
            if (!Session.pressKey(event.text.toLowerCase())) return;
        }
        event.accepted = true;
    }

    Repeater {
        model: Session.actions

        Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool selected: !Session.confirmAction && Session.selectedIndex === index
            readonly property bool confirming: Session.confirmAction?.id === modelData.id

            width: page.width
            height: 44
            radius: Theme.radius
            color: selected || confirming ? Theme.surface : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Icon {
                id: rowIcon
                anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                width: 24
                text: row.modelData.icon
                color: row.selected || row.confirming ? Theme.accent : Theme.foreground
            }

            Label {
                anchors {
                    left: rowIcon.right
                    right: keyHint.left
                    leftMargin: 10
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: row.modelData.label
                elide: Text.ElideRight
                font.weight: row.selected || row.confirming ? Font.Medium : Font.Normal
            }

            Label {
                id: keyHint
                anchors {
                    right: parent.right
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: row.modelData.key.toUpperCase()
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (!Session.confirmAction) Session.selectedIndex = row.index
                onClicked: Session.choose(row.modelData)
            }
        }
    }

    // The confirmation sits below the list so the view changes as little as possible.
    Item {
        width: parent.width
        height: 8
        visible: Session.confirmAction !== null
    }

    Rectangle {
        width: parent.width
        visible: Session.confirmAction !== null
        height: confirmLayout.implicitHeight + 24
        radius: Theme.radius
        color: Theme.surface

        Column {
            id: confirmLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 6

            Label {
                width: parent.width
                text: `${Session.confirmAction?.label ?? ""}?`
                font.weight: Font.DemiBold
            }

            Label {
                width: parent.width
                bottomPadding: 6
                wrapMode: Text.Wrap
                color: Theme.muted
                text: I18n.t("power.confirmWarning")
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                ConfirmButton {
                    text: I18n.t("common.cancel")
                    selected: !Session.confirmSelected
                    onClicked: Session.cancelConfirm()
                }

                ConfirmButton {
                    text: Session.confirmAction?.label ?? ""
                    selected: Session.confirmSelected
                    danger: true
                    onClicked: Session.run(Session.confirmAction)
                }
            }
        }
    }
}
