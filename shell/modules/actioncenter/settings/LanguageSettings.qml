import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Interface language: the system one, or any language with a file in i18n/, shown by its own name.
Column {
    id: root

    spacing: 2

    FolderListModel {
        id: files
        folder: `file://${Quickshell.shellDir}/i18n`
        nameFilters: ["*.json"]
        showDirs: false
    }

    ListRow {
        width: parent.width
        text: I18n.t("language.auto")
        selected: Settings.language === "auto"
        onClicked: Settings.set("language", undefined)
    }

    Repeater {
        model: files

        ListRow {
            id: row

            required property string fileBaseName
            required property string filePath

            width: root.width
            text: fileBaseName
            selected: Settings.language === fileBaseName
            onClicked: Settings.set("language", fileBaseName)

            FileView {
                path: row.filePath
                onLoaded: {
                    try {
                        row.text = JSON.parse(text())["language.name"] ?? row.fileBaseName;
                    } catch (e) {}
                }
            }
        }
    }
}
