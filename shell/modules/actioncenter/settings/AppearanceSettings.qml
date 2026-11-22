import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Dark or light theme for the shell and GTK applications, the icon theme, and the wallpaper: HyprDora's own,
// or any picture, which then shows after them.
Column {
    id: root

    // Three pictures to a row, in the screen's usual shape.
    readonly property real tileWidth: (width - 2 * 6) / 3

    component WallpaperTile: ClippingRectangle {
        id: tile

        property string path: ""
        readonly property bool selected: Wallpaper.current === path

        width: root.tileWidth
        height: Math.round(width * 10 / 16)
        radius: Theme.radius
        color: Theme.surface

        Image {
            anchors.fill: parent
            source: tile.path !== "" ? `file://${tile.path}` : ""
            sourceSize.width: 240
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            color: "transparent"
            border.width: tile.selected ? 2 : area.containsMouse ? 1 : 0
            border.color: tile.selected ? Theme.accent : Theme.muted
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Wallpaper.set(tile.path)
        }
    }

    spacing: 2

    SectionTitle {
        text: I18n.t("appearance.theme")
    }

    Repeater {
        model: ["dark", "light"]

        ListRow {
            required property string modelData

            width: parent.width
            text: I18n.t(`appearance.${modelData}`)
            selected: Settings.theme === modelData
            onClicked: Settings.set("theme", modelData === "dark" ? undefined : modelData)
        }
    }

    SectionTitle {
        topPadding: 8
        text: I18n.t("appearance.icons")
    }

    Repeater {
        model: Settings.iconThemes

        ListRow {
            required property string modelData

            width: parent.width
            text: modelData
            selected: Settings.iconTheme === modelData
            onClicked: Settings.set("iconTheme", modelData === "Papirus" ? undefined : modelData)
        }
    }

    SectionTitle {
        topPadding: 8
        text: I18n.t("appearance.wallpaper")
    }

    FolderListModel {
        id: wallpapers
        folder: `file://${Wallpaper.folder}`
        nameFilters: ["*.jpg", "*.png"]
        showDirs: false
    }

    Flow {
        width: parent.width
        spacing: 6

        Repeater {
            model: wallpapers

            WallpaperTile {
                required property string filePath

                path: filePath
            }
        }

        // A picture of one's own, after HyprDora's.
        WallpaperTile {
            visible: !Wallpaper.current.startsWith(`${Wallpaper.folder}/`)
            path: visible ? Wallpaper.current : ""
        }

        Rectangle {
            width: root.tileWidth
            height: Math.round(width * 10 / 16)
            radius: Theme.radius
            color: chooseArea.containsMouse ? Theme.surfaceHover : Theme.surface

            Icon {
                anchors.centerIn: parent
                text: Icons.plus
                color: Theme.muted
            }

            MouseArea {
                id: chooseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpaper.choose()
            }
        }
    }
}
