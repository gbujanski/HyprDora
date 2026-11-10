import QtQuick
import qs.config
import qs.components
import qs.services

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
        }
    ]
    readonly property int currentIndex: categories.findIndex(c => c.id === Panels.settingsCategory)
    readonly property var current: categories[currentIndex] ?? null
    readonly property int rowHeight: 34
    readonly property int rowSpacing: 2

    // Bottom-right corner of the settings button.
    property point anchor: Qt.point(0, 0)

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
        if (button)
            anchor = button.mapToItem(root, button.width, button.height);
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

    // A click anywhere outside the settings windows closes them and goes no further.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: Panels.settingsMenuOpen = false
    }

    Rectangle {
        id: menu

        x: root.anchor.x - width
        y: root.anchor.y + 4
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
                                Panels.settingsCategory = row.modelData.id;
                        }
                        onClicked: Panels.settingsCategory = row.modelData.id
                    }
                }
            }
        }
    }

    Rectangle {
        id: flyout

        visible: root.current !== null
        x: menu.x - width - 6
        // Level with the category's row, but always on screen.
        y: Math.max(Theme.panelMargin, Math.min(menu.y + root.currentIndex * (root.rowHeight + root.rowSpacing), root.height - height - Theme.panelMargin))
        width: 320
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

        Column {
            id: content

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.panelPadding
            }
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
                    default:
                        return null;
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
        width: 160
        height: optionList.implicitHeight + 12
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
        id: weatherSettings
        WeatherSettings {}
    }
}
