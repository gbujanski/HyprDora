import QtQuick
import qs.config

// A number with up and down arrows, used in time and date inputs. A click allows typing; once all its
// digits are typed, the next segment takes over. The wheel and the up and down keys change it by one,
// wrapping around within its range.
Column {
    id: root

    property int value: 0
    property int from: 0
    property int to: 99
    property int digits: 2
    // Leading zeros, as in 09:05; off for amounts such as 15.
    property bool pad: true
    // The segment that typing moves on to.
    property Item next: null
    property alias input: field

    signal edited(int value)

    /**
     * Writes a value as shown in the field.
     * @param {int} v  value
     * @returns {string}
     */
    function shown(v) {
        return pad ? String(v).padStart(digits, "0") : String(v);
    }

    /**
     * Sets a value, wrapping around the range.
     * @param {int} wanted  new value
     */
    function set(wanted) {
        const span = to - from + 1;
        const v = ((wanted - from) % span + span) % span + from;
        if (v !== value)
            root.edited(v);
    }

    spacing: 0

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Icons.chevronUp
        font.family: Theme.iconFamily
        font.pixelSize: Theme.iconSizeSmall
        color: upArea.containsMouse ? Theme.foreground : Theme.muted

        MouseArea {
            id: upArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.set(root.value + 1)
        }
    }

    TextInput {
        id: field

        /** Takes the typed number, within the range. */
        function commit() {
            const typed = parseInt(text, 10);
            if (!isNaN(typed))
                root.set(Math.max(root.from, Math.min(typed, root.to)));
            text = Qt.binding(() => root.shown(root.value));
        }

        width: root.digits * 13
        horizontalAlignment: Text.AlignHCenter
        text: root.shown(root.value)
        color: Theme.foreground
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeTitle
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
        maximumLength: root.digits
        validator: RegularExpressionValidator {
            regularExpression: /\d*/
        }
        selectByMouse: true

        onActiveFocusChanged: {
            if (activeFocus) {
                // Typing owns the text until the field is left, so a value set meanwhile does not jump in.
                text = root.shown(root.value);
                selectAll();
            } else {
                commit();
            }
        }
        // Every digit counts at once, so a button pressed while typing sees the typed value.
        onTextEdited: {
            const typed = parseInt(text, 10);
            if (!isNaN(typed))
                root.set(Math.max(root.from, Math.min(typed, root.to)));
            if (text.length === root.digits && root.next)
                root.next.input.forceActiveFocus();
        }
        onAccepted: commit()

        Keys.onUpPressed: root.set(root.value + 1)
        Keys.onDownPressed: root.set(root.value - 1)

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: -1
            }
            height: 1
            visible: field.activeFocus
            color: Theme.accent
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => root.set(root.value + (wheel.angleDelta.y > 0 ? 1 : -1))
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Icons.chevronDown
        font.family: Theme.iconFamily
        font.pixelSize: Theme.iconSizeSmall
        color: downArea.containsMouse ? Theme.foreground : Theme.muted

        MouseArea {
            id: downArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.set(root.value - 1)
        }
    }
}
