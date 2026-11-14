import QtQuick
import qs.config
import qs.components
import qs.services

// Online accounts: the signed-in ones with a way to sign out, and adding one by choosing a provider and
// signing in through its own page in the browser.
Column {
    id: root

    property string provider: OnlineAccounts.providers[0].value
    readonly property var providerInfo: OnlineAccounts.providers.find(p => p.value === provider)
    // Typed values by field key.
    property var values: ({})

    spacing: 8

    Repeater {
        model: OnlineAccounts.accounts

        Rectangle {
            required property var modelData

            width: root.width
            height: 48
            radius: Theme.radius
            color: Theme.surface

            Icon {
                id: accountIcon
                anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                text: Icons.cloud
                color: Theme.accent
            }

            Column {
                anchors {
                    left: accountIcon.right
                    right: signOut.left
                    leftMargin: 10
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width
                    text: OnlineAccounts.providers.find(p => p.value === parent.parent.modelData.provider)?.label ?? parent.parent.modelData.provider
                    font.weight: Font.Medium
                }

                Label {
                    width: parent.width
                    text: `${parent.parent.modelData.login} · ${parent.parent.modelData.server.replace(/^https?:\/\//, "")}`
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            TextButton {
                id: signOut
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: I18n.t("accounts.signOut")
                onClicked: OnlineAccounts.remove(parent.modelData)
            }
        }
    }

    SectionTitle {
        topPadding: OnlineAccounts.accounts.length > 0 ? 4 : 0
        text: I18n.t("accounts.add")
    }

    Dropdown {
        width: root.width
        title: I18n.t("accounts.provider")
        options: OnlineAccounts.providers.map(p => ({
                    value: p.value,
                    label: p.label
                }))
        currentValue: root.provider
        onSelected: value => {
            root.provider = value;
            root.values = {};
        }
    }

    Repeater {
        model: root.providerInfo?.fields ?? []

        Column {
            required property var modelData

            width: root.width
            spacing: 4

            Label {
                text: parent.modelData.label
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }

            TextField {
                width: parent.width
                placeholder: parent.modelData.placeholder
                text: root.values[parent.modelData.key] ?? ""
                onTextChanged: root.values = Object.assign({}, root.values, {
                    [parent.modelData.key]: text
                })
                onAccepted: OnlineAccounts.add(root.provider, root.values)
            }
        }
    }

    ErrorBanner {
        width: root.width
        text: OnlineAccounts.error
    }

    Row {
        spacing: 8
        visible: OnlineAccounts.state === ""

        TextButton {
            text: I18n.t("accounts.signIn")
            primary: true
            onClicked: OnlineAccounts.add(root.provider, root.values)
        }
    }

    Row {
        width: root.width
        spacing: 8
        visible: OnlineAccounts.state !== ""

        Spinner {
            anchors.verticalCenter: parent.verticalCenter
            running: parent.visible
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 120
            text: OnlineAccounts.state === "waiting" ? I18n.t("accounts.waiting") : I18n.t("accounts.starting")
            wrapMode: Text.WordWrap
        }

        TextButton {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("common.cancel")
            onClicked: OnlineAccounts.cancel()
        }
    }
}
