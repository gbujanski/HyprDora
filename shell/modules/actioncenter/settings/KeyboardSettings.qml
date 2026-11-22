import QtQuick
import qs.config
import qs.components
import qs.services

// Keyboard layouts: the first is the default; more than one shows a switch on the bar. A layout is added by
// searching all layouts and their variants by name.
Column {
    id: root

    property bool adding: false
    property string query: ""
    // Layouts and variants matching the search, not yet in use, the names starting with it first.
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        if (!adding || q === "")
            return [];
        const used = Input.layouts.map(l => `${l.layout}:${l.variant}`);
        const found = Input.catalog.filter(c => !used.includes(`${c.layout}:${c.variant}`) && (c.name.toLowerCase().includes(q) || c.layout === q));
        const starts = found.filter(c => c.name.toLowerCase().startsWith(q));
        return [...starts, ...found.filter(c => !starts.includes(c))].slice(0, 8);
    }

    /**
     * Moves a layout one place up, so the first becomes the default.
     * @param {int} index  place in the list
     */
    function moveUp(index) {
        const list = Input.layouts.slice();
        list.splice(index - 1, 0, list.splice(index, 1)[0]);
        Input.setLayouts(list);
    }

    /**
     * Removes a layout.
     * @param {int} index  place in the list
     */
    function remove(index) {
        Input.setLayouts(Input.layouts.filter((l, i) => i !== index));
    }

    /**
     * Adds a layout at the end and closes the search.
     * @param {object} entry  { layout, variant }
     */
    function addLayout(entry) {
        Input.setLayouts([...Input.layouts,
            {
                layout: entry.layout,
                variant: entry.variant
            }
        ]);
        adding = false;
        search.clear();
    }

    spacing: 2
    Component.onCompleted: Input.loadCatalog()

    SectionTitle {
        text: I18n.t("keyboard.layouts")
    }

    Repeater {
        model: Input.layouts

        ItemRow {
            id: layoutRow

            required property var modelData
            required property int index

            width: root.width
            icon: Icons.keyboardLayout
            title: Input.nameOf(modelData)
            subtitle: index === 0 && Input.layouts.length > 1 ? I18n.t("keyboard.default") : ""
            interactive: false

            trailing: Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                IconButton {
                    visible: layoutRow.index > 0
                    icon: Icons.arrowUp
                    iconColor: Theme.muted
                    tooltip: I18n.t("keyboard.moveUp")
                    onClicked: root.moveUp(layoutRow.index)
                }

                DeleteButton {
                    visible: Input.layouts.length > 1
                    label: I18n.t("keyboard.remove")
                    onConfirmed: root.remove(layoutRow.index)
                }
            }
        }
    }

    Item {
        width: root.width
        height: 8
    }

    TextButton {
        visible: !root.adding
        text: I18n.t("keyboard.add")
        onClicked: {
            root.adding = true;
            search.focusInput();
        }
    }

    TextField {
        id: search
        width: root.width
        visible: root.adding
        placeholder: I18n.t("keyboard.search")
        onTextChanged: root.query = text
        onAccepted: {
            if (root.matches.length > 0)
                root.addLayout(root.matches[0]);
        }
        onCancelled: {
            root.adding = false;
            clear();
        }
    }

    Repeater {
        model: root.matches

        ListRow {
            required property var modelData

            width: root.width
            text: modelData.name
            onClicked: root.addLayout(modelData)
        }
    }
}
