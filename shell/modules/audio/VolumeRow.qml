import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// One PipeWire node's volume: the icon mutes it, and the arrow on the right, when shown, unfolds more.
SliderRow {
    id: root

    property PwNode node: null
    property string emptyTitle: I18n.t("audio.noDevice")
    property bool isMicrophone: false
    property bool showChevron: false
    property string chevronIcon: Icons.chevronRight

    signal chevronClicked

    readonly property bool available: node?.audio !== undefined && node?.audio !== null
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property real volume: node?.audio?.volume ?? 0

    active: available
    // An application's row has no arrow and takes the whole width.
    reserveTrailing: showChevron
    iconClickable: true
    icon: isMicrophone ? Icons.microphone(muted) : Icons.volume(volume, muted)
    iconColor: muted ? Theme.muted : Theme.foreground
    iconTooltip: muted ? I18n.t("audio.unmute") : I18n.t("audio.mute")
    title: available ? Audio.displayName(node) : emptyTitle
    titleColor: available ? Theme.foreground : Theme.muted
    valueText: !available ? "" : muted ? I18n.t("audio.muted") : `${Math.round(volume * 100)}%`
    value: volume
    onIconClicked: Audio.toggleNodeMute(node)
    onMoved: value => Audio.setNodeVolume(node, value)

    trailing: IconButton {
        visible: root.showChevron
        icon: root.chevronIcon
        iconColor: Theme.muted
        tooltip: I18n.t("audio.devicesAndApps")
        onClicked: root.chevronClicked()
    }
}
