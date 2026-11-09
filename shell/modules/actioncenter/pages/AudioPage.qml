import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services
import qs.modules.actioncenter

Column {
    spacing: 14

    // Full data for all nodes is needed only while this page is open.
    PwObjectTracker {
        objects: [...Audio.sinks, ...Audio.sources, ...Audio.playbackStreams]
    }

    Column {
        width: parent.width
        spacing: 2

        SectionTitle {
            text: I18n.t("section.output")
        }

        VolumeRow {
            width: parent.width
            node: Audio.sink
            emptyTitle: I18n.t("audio.noOutput")
        }

        Repeater {
            model: ScriptModel {
                values: Audio.sinks
            }

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

        SectionTitle {
            text: I18n.t("section.input")
        }

        VolumeRow {
            width: parent.width
            node: Audio.source
            emptyTitle: I18n.t("audio.noMicrophone")
            isMicrophone: true
        }

        Repeater {
            model: ScriptModel {
                values: Audio.sources
            }

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

        SectionTitle {
            text: I18n.t("section.applications")
        }

        Label {
            visible: Audio.playbackStreams.length === 0
            text: I18n.t("audio.noStreams")
            color: Theme.muted
            topPadding: 4
            bottomPadding: 4
        }

        Repeater {
            model: ScriptModel {
                values: Audio.playbackStreams
            }

            VolumeRow {
                required property var modelData
                width: parent.width
                node: modelData
            }
        }
    }
}
