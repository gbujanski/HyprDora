import QtQuick
import qs.config

Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool secret: false
    property bool revealed: false

    signal accepted()
    signal cancelled()

    function focusInput() { input.forceActiveFocus(); }
    function clear() { input.text = ""; revealed = false; }

    implicitHeight: 34
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.surfaceHover

    TextInput {
        id: input
        anchors {
            left: parent.left
            right: eye.visible ? eye.left : parent.right
            leftMargin: 10
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        color: Theme.foreground
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true
        echoMode: root.secret && !root.revealed ? TextInput.Password : TextInput.Normal
        // Input method hints are off so a password never reaches their history.
        inputMethodHints: root.secret ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText : Qt.ImhNone
        activeFocusOnTab: true
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.cancelled()

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Theme.muted
        }
    }

    IconButton {
        id: eye
        anchors {
            right: parent.right
            rightMargin: 2
            verticalCenter: parent.verticalCenter
        }
        visible: root.secret
        icon: Icons.eye(root.revealed)
        iconColor: Theme.muted
        tooltip: root.revealed ? I18n.t("password.hide") : I18n.t("password.show")
        onClicked: root.revealed = !root.revealed
    }
}
