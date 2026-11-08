import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Bieżąca pogoda i prognoza na kolejne dni.
Column {
    id: root

    readonly property var dayNames: ["Nd", "Pn", "Wt", "Śr", "Cz", "Pt", "So"]
    readonly property var current: Weather.current

    function dayLabel(iso, index) {
        if (index === 0) return "Dziś";
        const [y, m, d] = iso.split("-").map(Number);
        return dayNames[new Date(y, m - 1, d).getDay()];
    }

    function formatNumber(value) {
        return String(Math.round(value));
    }

    spacing: 10

    Item {
        width: parent.width
        height: 26

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: `POGODA · ${Settings.weatherPlace.toUpperCase()}`
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 4

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Weather.fetchedAt > 0
                text: Weather.loading ? "Odświeżanie…"
                    : new Date(Weather.fetchedAt).toLocaleTimeString(Qt.locale(), "HH:mm")
                color: Theme.dim
                font.pixelSize: Theme.fontSizeSmall
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 26
                implicitHeight: 26
                icon: Icons.refresh
                iconColor: Theme.muted
                active: !Weather.loading
                tooltip: "Odśwież"
                onClicked: Weather.refresh()
            }
        }
    }

    Label {
        width: parent.width
        visible: !Weather.available
        text: Weather.loading ? "Pobieranie pogody…" : (Weather.error || "Brak danych o pogodzie")
        color: Theme.muted
        wrapMode: Text.WordWrap
    }

    // Bieżące warunki.
    Row {
        visible: Weather.available
        width: parent.width
        spacing: 12

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? Icons.weather(root.current.code, root.current.isDay) : ""
            font.pixelSize: 34
            width: 40
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? Weather.formatTemp(root.current.temp) : ""
            font.pixelSize: 28
            font.weight: Font.Medium
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Label {
                text: root.current ? Weather.describe(root.current.code) : ""
                font.weight: Font.Medium
            }

            Label {
                text: root.current ? `Odczuwalna ${Weather.formatTemp(root.current.feels)}` : ""
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Row {
        visible: Weather.available
        spacing: 14

        Repeater {
            model: root.current ? [
                { icon: Icons.wind, text: `${root.formatNumber(root.current.wind)} km/h`, tip: "Wiatr" },
                { icon: Icons.humidity, text: `${root.formatNumber(root.current.humidity)}%`, tip: "Wilgotność" },
                { icon: Icons.sunrise, text: Weather.sunrise, tip: "Wschód słońca" },
                { icon: Icons.sunset, text: Weather.sunset, tip: "Zachód słońca" }
            ].filter(item => item.text !== "") : []

            Row {
                required property var modelData
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.icon
                    color: Theme.muted
                    font.pixelSize: 14
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // Prognoza dzienna.
    Row {
        id: forecast

        visible: Weather.available && Weather.daily.length > 0
        width: parent.width

        Repeater {
            model: Weather.daily

            Column {
                required property var modelData
                required property int index

                width: forecast.width / Math.max(1, Weather.daily.length)
                spacing: 3

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dayLabel(modelData.date, index)
                    color: index === 0 ? Theme.foreground : Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: index === 0 ? Font.DemiBold : Font.Normal
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.weather(modelData.code, true)
                    font.pixelSize: 20
                    height: 24
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.formatTemp(modelData.max)
                    font.weight: Font.Medium
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.formatTemp(modelData.min)
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Pusty wiersz zamiast znikania, żeby kolumny miały równą wysokość.
                    text: modelData.precipitation >= 20 ? `${modelData.precipitation}%` : " "
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall - 1
                }
            }
        }
    }

    Label {
        width: parent.width
        visible: Weather.available && Weather.error !== ""
        text: `${Weather.error}. Pokazuję ostatni wynik.`
        color: Theme.warning
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
