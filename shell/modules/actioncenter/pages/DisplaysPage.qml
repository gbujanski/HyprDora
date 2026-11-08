import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: page

    readonly property var monitor: Displays.selected
    readonly property bool multiple: Displays.monitors.length > 1
    readonly property bool canDisable: Displays.activeDraft.some(m => m.name !== monitor?.name)

    readonly property var resolutions: {
        const seen = [];
        const result = [];
        for (const mode of monitor?.modes ?? []) {
            const value = `${mode.width}x${mode.height}`;
            if (!seen.includes(value)) {
                seen.push(value);
                result.push({ value: value, label: `${mode.width} × ${mode.height}`, width: mode.width, height: mode.height });
            }
        }
        const current = monitor ? `${monitor.width}x${monitor.height}` : "";
        if (monitor && !seen.includes(current))
            result.unshift({ value: current, label: `${monitor.width} × ${monitor.height}`, width: monitor.width, height: monitor.height });
        return result;
    }

    readonly property var refreshRates: {
        if (!monitor) return [];
        const rates = monitor.modes
            .filter(m => m.width === monitor.width && m.height === monitor.height)
            .map(m => m.refresh);
        if (!rates.some(r => Math.abs(r - monitor.refresh) < 0.01)) rates.unshift(monitor.refresh);
        return rates.map(r => ({ value: r, label: `${r.toFixed(2)} Hz` }));
    }

    function closestRefresh(width, height) {
        const rates = monitor.modes.filter(m => m.width === width && m.height === height).map(m => m.refresh);
        return rates.length > 0 ? rates[0] : monitor.refresh;
    }

    spacing: 12

    Component.onCompleted: Displays.refresh()
    Component.onDestruction: if (!Displays.pending) Displays.resetDraft()

    ErrorBanner {
        width: parent.width
        text: Displays.errorMessage
    }

    Column {
        width: parent.width
        spacing: 6
        visible: page.multiple

        SectionTitle { text: I18n.t("section.mode") }

        Grid {
            width: parent.width
            columns: 2
            spacing: 6

            Repeater {
                model: [
                    { id: "extend", label: I18n.t("displays.extend") },
                    { id: "mirror", label: I18n.t("displays.mirror") },
                    { id: "internal", label: I18n.t("displays.internalOnly") },
                    { id: "external", label: I18n.t("displays.externalOnly") }
                ]

                TextButton {
                    required property var modelData
                    width: (parent.width - parent.spacing) / 2
                    text: modelData.label
                    active: !Displays.pending
                    onClicked: Displays.applyPreset(modelData.id)
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 6
        visible: page.multiple && Displays.activeDraft.length > 0

        SectionTitle { text: I18n.t("section.layout") }

        DisplayLayout {
            width: parent.width
        }

        Label {
            visible: Displays.activeDraft.length > 1
            text: I18n.t("displays.dragHint")
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: page.multiple

        SectionTitle { text: I18n.t("section.screens") }

        Repeater {
            model: Displays.draft

            ListRow {
                required property var modelData
                width: parent.width
                text: `${Displays.displayName(modelData)} (${modelData.name})`
                selected: Displays.selected?.name === modelData.name
                onClicked: Displays.select(modelData.name)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 4
        visible: page.monitor !== null

        SectionTitle {
            width: parent.width
            elide: Text.ElideRight
            text: page.monitor ? Displays.displayName(page.monitor).toUpperCase() : ""
        }

        Item {
            width: parent.width
            height: 34

            Label {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: page.monitor?.mirrorOf ? I18n.t("displays.mirrorOf", { screen: page.monitor.mirrorOf }) : I18n.t("displays.enabled")
                color: Theme.muted
            }

            Switch {
                anchors {
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                checked: page.monitor?.enabled ?? false
                // The last active screen cannot be turned off.
                active: !(page.monitor?.enabled ?? false) || page.canDisable
                onToggled: Displays.setEnabled(page.monitor.name, !page.monitor.enabled)
            }
        }

        Dropdown {
            width: parent.width
            visible: page.monitor?.enabled ?? false
            title: I18n.t("displays.resolution")
            options: page.resolutions
            currentValue: page.monitor ? `${page.monitor.width}x${page.monitor.height}` : ""
            onSelected: value => {
                const option = page.resolutions.find(o => o.value === value);
                Displays.setMode(page.monitor.name, option.width, option.height, page.closestRefresh(option.width, option.height));
            }
        }

        Dropdown {
            width: parent.width
            visible: page.monitor?.enabled ?? false
            title: I18n.t("displays.refresh")
            options: page.refreshRates
            currentValue: page.monitor?.refresh
            onSelected: value => Displays.setMode(page.monitor.name, page.monitor.width, page.monitor.height, value)
        }

        Item {
            width: parent.width
            height: 34
            visible: page.monitor?.enabled ?? false

            Label {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: I18n.t("displays.scale")
                color: Theme.muted
            }

            SegmentedControl {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: 230
                implicitHeight: 30
                currentValue: page.monitor?.scale
                options: [1, 1.25, 1.5, 2].map(s => ({ value: s, label: `${s}` }))
                onSelected: value => Displays.setScale(page.monitor.name, value)
            }
        }
    }

    Row {
        anchors.right: parent.right
        spacing: 6
        visible: Displays.dirty && !Displays.pending

        TextButton {
            text: I18n.t("displays.discard")
            onClicked: Displays.resetDraft()
        }

        TextButton {
            text: I18n.t("displays.apply")
            primary: true
            onClicked: Displays.applyDraft()
        }
    }
}
