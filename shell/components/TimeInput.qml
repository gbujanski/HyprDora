import QtQuick
import qs.config

// A time as hours and minutes, each with up and down arrows. Typing 2223 sets 22:23: two digits of the
// hour move on to the minutes.
Row {
    id: root

    // Minutes after midnight.
    property int minutes: 0

    // Emitted with a new value; the owner decides whether to take it.
    signal edited(int minutes)

    spacing: 2

    NumberSegment {
        id: hours
        value: Math.floor(root.minutes / 60)
        to: 23
        next: minutesSegment
        onEdited: v => root.edited(v * 60 + root.minutes % 60)
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: ":"
        font.pixelSize: Theme.fontSizeTitle
        font.weight: Font.Medium
    }

    NumberSegment {
        id: minutesSegment
        value: root.minutes % 60
        to: 59
        onEdited: v => root.edited(Math.floor(root.minutes / 60) * 60 + v)
    }
}
