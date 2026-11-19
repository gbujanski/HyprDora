import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.actioncenter.pages
import qs.modules.actioncenter.settings

// Quick settings at the bar's right end: the main page, the subpages for Wi-Fi, Bluetooth, VPN and power,
// and the settings menu beside the panel.
BarPanel {
    id: frame

    readonly property var pageTitles: ({
            wifi: "Wi-Fi",
            bluetooth: "Bluetooth",
            power: I18n.t("page.power"),
            vpn: "VPN"
        })

    name: "actioncenter"
    slideSideways: true
    onBackgroundClicked: Panels.settingsMenuOpen = false

    content: Component {
        Item {
            id: layout

            readonly property int headerSpace: header.visible ? header.height + 10 : 0
            readonly property real contentHeight: headerSpace + flick.contentHeight

            implicitHeight: contentHeight
            focus: true

            // Esc closes the settings menu, returns from a subpage to the main view, and from there is
            // left to the frame, which closes the panel.
            Keys.onEscapePressed: event => {
                if (Panels.settingsMenuOpen)
                    Panels.settingsMenuOpen = false;
                else if (Panels.actionCenterPage !== "main")
                    Panels.actionCenterPage = "main";
                else
                    event.accepted = false;
            }

            Row {
                id: header

                visible: Panels.actionCenterPage !== "main"
                spacing: 6

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.back
                    tooltip: I18n.t("nav.back")
                    onClicked: Panels.actionCenterPage = "main"
                }

                Title {
                    anchors.verticalCenter: parent.verticalCenter
                    text: frame.pageTitles[Panels.actionCenterPage] ?? ""
                }
            }

            ScrollArea {
                id: flick

                anchors {
                    fill: parent
                    topMargin: layout.headerSpace
                }
                contentHeight: pageLoader.item?.implicitHeight ?? 0
                // Menus are placed by what opened them, so they would be left behind by scrolling.
                onContentYChanged: Panels.settingsMenuOpen = false

                Loader {
                    id: pageLoader
                    width: flick.usableWidth
                    sourceComponent: {
                        switch (Panels.actionCenterPage) {
                        case "wifi":
                            return wifiPage;
                        case "bluetooth":
                            return bluetoothPage;
                        case "power":
                            return powerPage;
                        case "vpn":
                            return vpnPage;
                        default:
                            return mainPage;
                        }
                    }
                    onSourceComponentChanged: flick.contentY = 0
                    // A destroyed page takes focus with it, and Esc would stop working.
                    onLoaded: (item.wantsFocus ? item : layout).forceActiveFocus()
                }

                Connections {
                    target: pageLoader.item
                    ignoreUnknownSignals: true
                    function onScrollToTop() {
                        flick.contentY = 0;
                    }
                }
            }

            Component {
                id: mainPage
                MainPage {}
            }

            Component {
                id: wifiPage
                WifiPage {}
            }

            Component {
                id: bluetoothPage
                BluetoothPage {}
            }

            Component {
                id: powerPage
                PowerPage {}
            }

            Component {
                id: vpnPage
                VpnPage {}
            }
        }
    }

    beside: Component {
        SettingsMenu {
            actionCenter: frame.panel
            opacity: frame.panel?.opacity ?? 0
        }
    }
}
