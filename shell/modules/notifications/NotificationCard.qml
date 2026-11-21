import QtQuick
import qs.config
import qs.components
import qs.services

// Card shared by toasts and the history in the notification panel.
Rectangle {
    id: root

    required property var notification
    property bool floating: false
    readonly property bool hovered: hover.hovered
    readonly property bool critical: notification.urgency === 2

    signal activated

    implicitHeight: Math.max(content.implicitHeight, 36) + 20
    radius: Theme.panelRadius - 2
    color: floating ? Theme.background : Theme.surface
    border.width: floating || critical ? 1 : 0
    border.color: critical ? Theme.error : Theme.surface

    HoverHandler {
        id: hover
    }

    // Clicking the body runs the application's default action, if it has one.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The default action, or else the application that sent the notification.
        onClicked: {
            if (Notifications.invokeDefault(root.notification) || Notifications.openSender(root.notification))
                root.activated();
        }
    }

    Item {
        id: iconBox
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 10
            topMargin: 10
        }
        width: 36
        height: 36

        Image {
            id: image
            anchors.fill: parent
            source: Notifications.iconSource(root.notification)
            sourceSize.width: 72
            sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        Icon {
            anchors.centerIn: parent
            visible: !image.visible
            text: Icons.bell
            color: Theme.muted
            font.pixelSize: Theme.iconSizeImage
        }
    }

    Column {
        id: content
        anchors {
            left: iconBox.right
            right: closeButton.left
            top: parent.top
            leftMargin: 10
            rightMargin: 4
            topMargin: 10
        }
        spacing: 2

        Label {
            width: parent.width
            text: `${root.notification.appName}${root.floating ? "" : "  ·  " + Notifications.relativeTime(root.notification)}`
            textFormat: Text.PlainText
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            visible: text !== ""
        }

        Label {
            width: parent.width
            text: root.notification.summary
            textFormat: Text.PlainText
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: Notifications.plainBody(root.notification.body)
            textFormat: Text.PlainText
            color: Theme.muted
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            visible: text !== ""
        }

        Flow {
            width: parent.width
            topPadding: 4
            spacing: 4
            visible: actionRepeater.count > 0

            Repeater {
                id: actionRepeater
                model: Notifications.visibleActions(root.notification)

                TextButton {
                    required property var modelData
                    text: modelData.text
                    // The action can close the notification and destroy this card, so it runs last.
                    onClicked: {
                        const action = modelData;
                        root.activated();
                        action.invoke();
                    }
                }
            }
        }
    }

    IconButton {
        id: closeButton
        anchors {
            right: parent.right
            top: parent.top
            margins: 4
        }
        icon: Icons.close
        iconColor: Theme.muted
        tooltip: I18n.t("notifications.remove")
        onClicked: root.notification.dismiss()
    }
}
