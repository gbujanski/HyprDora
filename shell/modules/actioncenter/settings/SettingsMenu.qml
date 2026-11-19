import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.displays

// Category list under the action center's settings button. Hovering a category opens its settings beside the list.
Item {
    id: root

    // In groups, with a line between them: devices; look and behaviour; region; account and system.
    readonly property var categories: [
        {
            id: "displays",
            label: I18n.t("settings.displays"),
            icon: Icons.monitor,
            group: 0
        },
        // Only on a computer with a touchpad.
        ...(Touchpad.present ? [
                {
                    id: "touchpad",
                    label: I18n.t("settings.touchpad"),
                    icon: Icons.touchpad,
                    group: 0
                }
            ] : []),
        {
            id: "printers",
            label: I18n.t("settings.printers"),
            icon: Icons.printer,
            group: 0
        },
        {
            id: "appearance",
            label: I18n.t("settings.appearance"),
            icon: Icons.palette,
            group: 1
        },
        {
            id: "idle",
            label: I18n.t("settings.idle"),
            icon: Icons.idle,
            group: 1
        },
        {
            id: "automations",
            label: I18n.t("settings.automations"),
            icon: Icons.automation,
            group: 1
        },
        {
            id: "defaultApps",
            label: I18n.t("settings.defaultApps"),
            icon: Icons.apps,
            group: 1
        },
        {
            id: "shortcuts",
            label: I18n.t("settings.shortcuts"),
            icon: Icons.keyboard,
            group: 1
        },
        {
            id: "language",
            label: I18n.t("settings.language"),
            icon: Icons.language,
            group: 2
        },
        {
            id: "weather",
            label: I18n.t("settings.weather"),
            icon: Icons.place,
            group: 2
        },
        {
            id: "accounts",
            label: I18n.t("settings.accounts"),
            icon: Icons.cloud,
            group: 3
        },
        {
            id: "restore",
            label: I18n.t("settings.restore"),
            icon: Icons.restore,
            group: 3
        },
        {
            id: "about",
            label: I18n.t("settings.about"),
            icon: Icons.info,
            group: 3
        }
    ]
    readonly property int currentIndex: categories.findIndex(c => c.id === Panels.settingsCategory)
    readonly property var current: categories[currentIndex] ?? null
    readonly property int rowHeight: 34
    readonly property int rowSpacing: 2
    // The line between groups, with its margins.
    readonly property int groupGap: 9
    // Where the current row starts in the list, past the rows and group lines above it.
    readonly property real currentOffset: currentIndex < 0 ? 0 : currentIndex * (rowHeight + rowSpacing) + categories.slice(1, currentIndex + 1).filter((c, i) => c.group !== categories[i].group).length * (groupGap + rowSpacing)

    // The action center panel, to tell a click on it from a click outside.
    property Item actionCenter: null

    // Bottom-right corner of the settings button, and the top of the button.
    property point anchor: Qt.point(0, 0)
    property real anchorTop: 0

    // Choices for one setting, shown beside the category's settings: { owner, y, options, current, select }.
    property var submenu: null

    /**
     * Opens the choices for a setting beside its row.
     * @param {Item} owner  row of the setting
     * @param {array} options  [{ value, label }]
     * @param {var} current  current value
     * @param {function} select  called with the chosen value
     */
    function openSubmenu(owner, options, current, select) {
        submenu = {
            owner: owner,
            y: owner.mapToItem(root, 0, 0).y,
            options: options,
            current: current,
            select: select
        };
    }

    /** Places the menu under the settings button. */
    function place() {
        const button = Panels.settingsButton;
        if (button) {
            anchor = button.mapToItem(root, button.width, button.height);
            anchorTop = anchor.y - button.height;
        }
    }

    // Hidden until placed, so it never flashes in a corner.
    visible: Panels.settingsMenuOpen && anchor.x > 0
    onVisibleChanged: submenu = null

    // When the menu opens together with the panel, the button settles only after layout and the slide-in.
    Timer {
        id: placeDelay
        interval: Theme.animPanel + 20
        onTriggered: root.place()
    }

    Connections {
        target: Panels
        function onSettingsMenuOpenChanged() {
            if (!Panels.settingsMenuOpen)
                return;
            root.place();
            placeDelay.restart();
        }
        // The button goes with the main page, as when the action center closes; there is nothing to place then.
        function onSettingsButtonChanged() {
            if (Panels.settingsButton)
                placeDelay.restart();
        }
        function onSettingsCategoryChanged() {
            root.submenu = null;
        }
    }

    // A click outside the settings windows closes only them when it lands on the action center, and the
    // whole action center anywhere else, as a click outside the action center always does.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            const panel = root.actionCenter;
            const inside = panel && panel.contains(panel.mapFromItem(this, mouse.x, mouse.y));
            if (inside)
                Panels.settingsMenuOpen = false;
            else
                Panels.close("actioncenter");
        }
    }

    Rectangle {
        id: menu

        x: root.anchor.x - width
        // Under the button when it fits, otherwise above it, and always within the screen.
        y: {
            const below = root.anchor.y + 4;
            const above = root.anchorTop - 4 - height;
            const preferred = below + height <= root.height - Theme.panelMargin ? below : above;
            return Math.max(Theme.panelMargin, Math.min(preferred, root.height - height - Theme.panelMargin));
        }
        width: 220
        height: list.implicitHeight + 12
        radius: Theme.panelRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.surface

        // Absorbs clicks so they do not reach the panel or the closing area.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        }

        Column {
            id: list

            anchors {
                fill: parent
                margins: 6
            }
            spacing: root.rowSpacing

            Repeater {
                model: root.categories

                Column {
                    id: entry

                    required property var modelData
                    required property int index

                    width: list.width
                    spacing: root.rowSpacing

                    // A line before the first category of a group.
                    Item {
                        width: entry.width
                        height: root.groupGap
                        visible: entry.index > 0 && root.categories[entry.index - 1].group !== entry.modelData.group

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: 8
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            height: 1
                            color: Theme.surface
                        }
                    }

                    // Hovering a category opens it, as a click does.
                    ItemRow {
                        id: row

                        readonly property var modelData: entry.modelData
                        readonly property bool current: Panels.settingsCategory === modelData.id

                        width: list.width
                        height: root.rowHeight
                        icon: modelData.icon
                        iconColor: current ? Theme.accent : Theme.muted
                        title: modelData.label
                        highlighted: current
                        onHoveredChanged: {
                            if (hovered)
                                Panels.settingsCategory = modelData.id;
                        }
                        onClicked: Panels.settingsCategory = modelData.id

                        trailing: Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            rightPadding: 4
                            text: Icons.chevronRight
                            color: Theme.muted
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: flyout

        visible: root.current !== null
        // Beside the list, but never past the left edge of the screen.
        x: Math.max(Theme.panelMargin, menu.x - width - 6)
        // Level with the category's row, but always on screen.
        y: Math.max(Theme.panelMargin, Math.min(menu.y + root.currentOffset, root.height - height - Theme.panelMargin))
        // The display layout needs the width of the panel.
        width: ["displays", "shortcuts", "automations", "accounts", "printers", "about"].includes(Panels.settingsCategory) ? Theme.panelWidth : 320
        height: Math.min(content.implicitHeight + Theme.panelPadding * 2, root.height - Theme.panelMargin * 2)
        radius: Theme.panelRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.surface
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        }

        // Scrolls when the settings are taller than the screen.
        ScrollArea {
            id: settingsScroll

            anchors {
                fill: parent
                margins: Theme.panelPadding
            }
            contentHeight: content.implicitHeight

            Column {
                id: content

                width: settingsScroll.usableWidth
                spacing: 10

                Title {
                    text: root.current?.label ?? ""
                }

                Loader {
                    width: parent.width
                    onLoaded: {
                        if ("menu" in item)
                            item.menu = root;
                    }
                    sourceComponent: {
                        switch (Panels.settingsCategory) {
                        case "idle":
                            return idleSettings;
                        case "language":
                            return languageSettings;
                        case "weather":
                            return weatherSettings;
                        case "displays":
                            return displaySettings;
                        case "shortcuts":
                            return shortcutsSettings;
                        case "defaultApps":
                            return defaultAppsSettings;
                        case "automations":
                            return automationsSettings;
                        case "appearance":
                            return appearanceSettings;
                        case "touchpad":
                            return touchpadSettings;
                        case "restore":
                            return restoreSettings;
                        case "accounts":
                            return accountsSettings;
                        case "printers":
                            return printersSettings;
                        case "about":
                            return aboutSettings;
                        default:
                            return null;
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: options

        visible: root.submenu !== null
        x: flyout.x - width - 6
        y: Math.max(Theme.panelMargin, Math.min((root.submenu?.y ?? 0) - 6, root.height - height - Theme.panelMargin))
        // As wide as the longest choice, so names such as application names fit, within the screen.
        width: Math.min(Math.max(160, ...(root.submenu?.options ?? []).map(o => optionMetrics.advanceWidth(o.label))) + 12 + 10 + 8 + 30, flyout.x - Theme.panelMargin - 6)
        height: optionList.implicitHeight + 12

        // Measures a selected label, which is the widest form because it is drawn medium.
        FontMetrics {
            id: optionMetrics
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
        }
        radius: Theme.panelRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.surface

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        }

        Column {
            id: optionList

            anchors {
                fill: parent
                margins: 6
            }
            spacing: root.rowSpacing

            Repeater {
                model: root.submenu?.options ?? []

                ListRow {
                    required property var modelData
                    width: optionList.width
                    text: modelData.label
                    selected: modelData.value === root.submenu?.current
                    onClicked: {
                        root.submenu.select(modelData.value);
                        root.submenu = null;
                    }
                }
            }
        }
    }

    Component {
        id: idleSettings
        IdleSettings {}
    }

    Component {
        id: languageSettings
        LanguageSettings {}
    }

    Component {
        id: aboutSettings
        AboutSettings {}
    }

    Component {
        id: printersSettings
        PrintersSettings {}
    }

    Component {
        id: accountsSettings
        AccountsSettings {}
    }

    Component {
        id: appearanceSettings
        AppearanceSettings {}
    }

    Component {
        id: touchpadSettings
        TouchpadSettings {}
    }

    Component {
        id: restoreSettings
        RestoreSettings {}
    }

    Component {
        id: automationsSettings
        AutomationsSettings {}
    }

    Component {
        id: defaultAppsSettings
        DefaultAppsSettings {}
    }

    Component {
        id: shortcutsSettings
        ShortcutsSettings {}
    }

    Component {
        id: displaySettings
        DisplaysPage {}
    }

    Component {
        id: weatherSettings
        WeatherSettings {}
    }
}
