import QtQuick
import qs.config
import qs.components

// Month grid from Monday with ISO week numbers. Always six rows,
// so the panel keeps its height across months.
Column {
    id: root

    property int year: 2000
    property int month: 0
    property date today: new Date()

    readonly property var dayNames: [1, 2, 3, 4, 5, 6, 0].map(day => I18n.shortDayName(day))
    readonly property real cellWidth: width / 8
    readonly property int cellHeight: 32

    // 42 consecutive days from the Monday before the first of the month.
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;
        const result = [];
        for (let i = 0; i < 42; i++) result.push(new Date(year, month, 1 - offset + i));
        return result;
    }

    function isoWeek(day) {
        const t = new Date(Date.UTC(day.getFullYear(), day.getMonth(), day.getDate()));
        // The Thursday of the same week determines the ISO year and week number.
        t.setUTCDate(t.getUTCDate() + 3 - (t.getUTCDay() + 6) % 7);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    spacing: 0

    Row {
        Label {
            width: root.cellWidth
            height: 24
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("calendar.week")
            color: Theme.dim
            font.pixelSize: Theme.fontSizeSmall - 1
        }

        Repeater {
            model: root.dayNames

            Label {
                required property string modelData
                required property int index
                width: root.cellWidth
                height: 24
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Theme.dim : Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }
        }
    }

    Repeater {
        model: 6

        Row {
            id: week

            required property int index
            readonly property var weekDays: root.days.slice(index * 7, index * 7 + 7)

            Label {
                width: root.cellWidth
                height: root.cellHeight
                horizontalAlignment: Text.AlignHCenter
                text: String(root.isoWeek(week.weekDays[0]))
                color: Theme.dim
                font.pixelSize: Theme.fontSizeSmall - 1
                font.features: { "tnum": 1 }
            }

            Repeater {
                model: week.weekDays

                Item {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool inMonth: modelData.getMonth() === root.month
                    readonly property bool isToday: root.sameDay(modelData, root.today)

                    width: root.cellWidth
                    height: root.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: cell.isToday ? Theme.accent : "transparent"
                    }

                    Label {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: String(cell.modelData.getDate())
                        font.features: { "tnum": 1 }
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                        color: cell.isToday ? Theme.accentText
                            : !cell.inMonth ? Theme.dim
                            : cell.index >= 5 ? Theme.muted
                            : Theme.foreground
                    }
                }
            }
        }
    }
}
