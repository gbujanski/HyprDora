import QtQuick
import qs.config

// A date as day, month and year, each with up and down arrows. Typing 31122026 sets 31.12.2026: each
// part moves on to the next once its digits are typed. A day past the end of the month is shortened.
Row {
    id: root

    property date date: new Date()

    // Emitted with a new date; the owner decides whether to take it.
    signal edited(date date)

    /**
     * Builds a date, keeping the day within the month.
     * @param {int} year  year
     * @param {int} month  month, 0 to 11
     * @param {int} day  day of the month
     * @returns {date}
     */
    function make(year, month, day) {
        const last = new Date(year, month + 1, 0).getDate();
        return new Date(year, month, Math.min(day, last));
    }

    spacing: 2

    NumberSegment {
        id: day
        value: root.date.getDate()
        from: 1
        to: new Date(root.date.getFullYear(), root.date.getMonth() + 1, 0).getDate()
        next: month
        onEdited: v => root.edited(root.make(root.date.getFullYear(), root.date.getMonth(), v))
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: "."
        font.pixelSize: Theme.fontSizeTitle
        font.weight: Font.Medium
    }

    NumberSegment {
        id: month
        value: root.date.getMonth() + 1
        from: 1
        to: 12
        next: year
        onEdited: v => root.edited(root.make(root.date.getFullYear(), v - 1, root.date.getDate()))
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: "."
        font.pixelSize: Theme.fontSizeTitle
        font.weight: Font.Medium
    }

    NumberSegment {
        id: year
        value: root.date.getFullYear()
        from: 2000
        to: 2099
        digits: 4
        onEdited: v => root.edited(root.make(v, root.date.getMonth(), root.date.getDate()))
    }
}
