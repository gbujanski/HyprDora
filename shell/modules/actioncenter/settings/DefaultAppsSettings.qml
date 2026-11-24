import QtQuick
import qs.config
import qs.components
import qs.services

// Default applications by kind. Hovering a row opens the installed applications beside it.
Column {
    id: root

    // The settings menu, which shows the choices.
    property Item menu: null

    spacing: 2

    Component.onCompleted: DefaultApps.refresh()

    Repeater {
        model: DefaultApps.kinds

        ChoiceRow {
            required property var modelData
            readonly property var app: DefaultApps.apps[modelData.id] ?? null

            width: root.width
            menu: root.menu
            title: I18n.t(`defaultApps.${modelData.id}`)
            valueText: app?.current ? DefaultApps.name(app.current) : "—"
            options: (app?.choices ?? []).map(id => ({
                        value: id,
                        label: DefaultApps.name(id)
                    }))
            current: app?.current ?? null
            onSelected: id => DefaultApps.set(modelData.id, id)
        }
    }
}
