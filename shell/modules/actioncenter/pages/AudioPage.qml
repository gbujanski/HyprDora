import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services
import qs.modules.actioncenter

Column {
    spacing: 14

    // Pełne dane wszystkich węzłów są potrzebne tylko przy otwartej stronie.
    PwObjectTracker {
        objects: [...Audio.sinks, ...Audio.sources, ...Audio.playbackStreams]
    }

    Column {
        width: parent.width
        spacing: 2

        SectionTitle { text: "WYJŚCIE" }

        VolumeRow {
            width: parent.width
            node: Audio.sink
            emptyTitle: "Brak wyjścia dźwięku"
        }

        Repeater {
            model: ScriptModel { values: Audio.sinks }

            ListRow {
                required property var modelData
                width: parent.width
                text: Audio.displayName(modelData)
                selected: modelData === Audio.sink
                onClicked: Audio.selectSink(modelData)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2

        SectionTitle { text: "WEJŚCIE" }

        VolumeRow {
            width: parent.width
            node: Audio.source
            emptyTitle: "Brak mikrofonu"
            isMicrophone: true
        }

        Repeater {
            model: ScriptModel { values: Audio.sources }

            ListRow {
                required property var modelData
                width: parent.width
                text: Audio.displayName(modelData)
                selected: modelData === Audio.source
                onClicked: Audio.selectSource(modelData)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2

        SectionTitle { text: "APLIKACJE" }

        Label {
            visible: Audio.playbackStreams.length === 0
            text: "Żadna aplikacja nie odtwarza dźwięku"
            color: Theme.muted
            topPadding: 4
            bottomPadding: 4
        }

        Repeater {
            model: ScriptModel { values: Audio.playbackStreams }

            VolumeRow {
                required property var modelData
                width: parent.width
                node: modelData
            }
        }
    }
}
