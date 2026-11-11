import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Volume of the output or the microphone. The arrow unfolds the devices to switch to and the volume of
// each application below it; one section is unfolded at a time.
Column {
    id: root

    property bool isMicrophone: false

    readonly property string key: isMicrophone ? "input" : "output"
    readonly property bool expanded: Panels.audioExpanded === key
    readonly property var devices: isMicrophone ? Audio.sources : Audio.sinks
    readonly property var streams: isMicrophone ? Audio.recordingStreams : Audio.playbackStreams

    spacing: 2

    // Full data for the listed nodes is needed only while the list is open.
    PwObjectTracker {
        objects: root.expanded ? [...root.devices, ...root.streams] : []
    }

    VolumeRow {
        width: root.width
        node: root.isMicrophone ? Audio.source : Audio.sink
        emptyTitle: root.isMicrophone ? I18n.t("audio.noMicrophone") : I18n.t("audio.noOutput")
        isMicrophone: root.isMicrophone
        showChevron: true
        chevronIcon: root.expanded ? Icons.chevronUp : Icons.chevronDown
        onChevronClicked: Panels.audioExpanded = root.expanded ? "" : root.key
    }

    Column {
        width: root.width
        visible: root.expanded
        spacing: 2
        topPadding: 2
        bottomPadding: 6

        Repeater {
            model: ScriptModel {
                values: root.devices
            }

            ListRow {
                required property var modelData
                width: root.width
                text: Audio.displayName(modelData)
                selected: modelData === (root.isMicrophone ? Audio.source : Audio.sink)
                onClicked: root.isMicrophone ? Audio.selectSource(modelData) : Audio.selectSink(modelData)
            }
        }

        SectionTitle {
            topPadding: 8
            leftPadding: 4
            text: I18n.t("section.applications")
        }

        Label {
            visible: root.streams.length === 0
            leftPadding: 4
            text: I18n.t("audio.noStreams")
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
        }

        Repeater {
            model: ScriptModel {
                values: root.streams
            }

            VolumeRow {
                required property var modelData
                width: root.width
                node: modelData
                isMicrophone: root.isMicrophone
            }
        }
    }
}
