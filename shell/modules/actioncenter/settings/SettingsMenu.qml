import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.actioncenter.pages

// Category list under the action center's settings button. Hovering a category opens its settings beside the list.
Item {
    id: root

    readonly property var categories: [
        {
            id: "idle",
            label: I18n.t("settings.idle"),
            icon: Icons.idle
        },
        {
            id: "language",
            label: I18n.t("settings.language"),
            icon: Icons.language
        },
        {
            id: "weather",
            label: I18n.t("settings.weather"),
            icon: Icons.place
        },
        {
            id: "displays",
            label: I18n.t("settings.displays"),
            icon: Icons.monitor
        },
        {
            id: "automations",
            label: I18n.t("settings.automations"),
            icon: Icons.automation
        },
        {
            id: "defaultApps",
            label: I18n.t("settings.defaultApps"),
            icon: Icons.apps
        },
        {
            id: "shortcuts",
            label: I18n.t("settings.shortcuts"),
            icon: Icons.keyboard
        },
        // Actions rather than categories: a click runs them, after the administrator password.
        {
            id: "restore",
            label: I18n.t("settings.restore"),
            icon: Icons.restore,
            action: () => SystemRestore.open()
        },
        {
            id: "snapshot",
            label: I18n.t("settings.snapshot"),
            icon: Icons.snapshot,
            action: () => SystemRestore.create()
        }
    ]
    readonly property int currentIndex: categories.findIndex(c => c.id === Panels.settingsCategory)
    readonly property var current: categories[currentIndex] ?? null
    readonly property int rowHeight: 34
    readonly property int rowSpacing: 2

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
        function onSettingsButtonChanged() {
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
                Panels.closeActionCenter();
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

                Rectangle {
                    id: row

                    required property var modelData
                    readonly property bool current: Panels.settingsCategory === modelData.id

                    width: list.width
                    height: root.rowHeight
                    radius: Theme.radius
                    color: current || rowArea.containsMouse ? Theme.surface : "transparent"

                    Icon {
                        id: rowIcon
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.modelData.icon
                        color: row.current ? Theme.accent : Theme.muted
                    }

                    Label {
                        anchors {
                            left: rowIcon.right
                            right: chevron.left
                            leftMargin: 10
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.modelData.label
                        elide: Text.ElideRight
                    }

                    Icon {
                        id: chevron
                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        visible: !row.modelData.action
                        text: Icons.chevronRight
                        color: Theme.muted
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse)
                                Panels.settingsCategory = row.modelData.action ? "" : row.modelData.id;
                        }
                        onClicked: {
                            if (!row.modelData.action) {
                                Panels.settingsCategory = row.modelData.id;
                                return;
                            }
                            // The password prompt is an ordinary window, which the action center would cover.
                            Panels.closeActionCenter();
                            row.modelData.action();
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
        y: Math.max(Theme.panelMargin, Math.min(menu.y + root.currentIndex * (root.rowHeight + root.rowSpacing), root.height - height - Theme.panelMargin))
        // The display layout needs the width of the panel.
        width: ["displays", "shortcuts", "automations"].includes(Panels.settingsCategory) ? Theme.panelWidth : 320
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
        Flickable {
            anchors {
                fill: parent
                margins: Theme.panelPadding
            }
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: parent.width
                spacing: 10

                Label {
                    text: root.current?.label ?? ""
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
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
