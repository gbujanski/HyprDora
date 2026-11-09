import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.actioncenter.pages

Scope {
    id: root

    readonly property var pageTitles: ({
            audio: I18n.t("page.audio"),
            wifi: "Wi-Fi",
            bluetooth: "Bluetooth",
            power: I18n.t("page.power"),
            displays: I18n.t("page.displays")
        })

    // The window outlives closing briefly so the animation can finish.
    Connections {
        target: Panels
        function onActionCenterOpenChanged() {
            if (!Panels.actionCenterOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.actionCenterOpen || closeDelay.running

        // The window covers the screen below the bar: clicking outside the panel closes it,
        // and the bar stays clickable.
        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.actionCenterOpen

            Component.onCompleted: entered = true

            screen: Panels.actionCenterScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-actioncenter"
            // OnDemand, not Exclusive: with Exclusive, Hyprland routes all clicks to this layer
            // and the bar stops reacting. Focus still reaches the panel on open, so Esc works.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeActionCenter()
            }

            Rectangle {
                id: panel

                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: Theme.panelMargin
                    rightMargin: Theme.panelMargin
                }
                width: Theme.panelWidth
                height: Math.min(layout.contentHeight + Theme.panelPadding * 2, window.height - Theme.panelMargin * 2)
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                transform: Translate {
                    x: window.shown ? 0 : 16
                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animPanel
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animPanel
                    }
                }

                // Esc returns from a subpage to the main view, and closes the panel from there.
                Keys.onEscapePressed: {
                    if (Panels.actionCenterPage !== "main")
                        Panels.actionCenterPage = "main";
                    else
                        Panels.closeActionCenter();
                }

                // Absorbs clicks so they do not reach the closing area.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                }

                Item {
                    id: layout

                    readonly property int headerSpace: header.visible ? header.height + 10 : 0
                    readonly property real contentHeight: headerSpace + flick.contentHeight

                    anchors {
                        fill: parent
                        margins: Theme.panelPadding
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

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.pageTitles[Panels.actionCenterPage] ?? ""
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.DemiBold
                        }
                    }

                    Flickable {
                        id: flick

                        anchors {
                            fill: parent
                            topMargin: layout.headerSpace
                        }
                        contentWidth: width
                        contentHeight: pageLoader.item?.implicitHeight ?? 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Loader {
                            id: pageLoader
                            width: flick.width - (flick.contentHeight > flick.height ? 8 : 0)
                            sourceComponent: {
                                switch (Panels.actionCenterPage) {
                                case "audio":
                                    return audioPage;
                                case "wifi":
                                    return wifiPage;
                                case "bluetooth":
                                    return bluetoothPage;
                                case "power":
                                    return powerPage;
                                case "displays":
                                    return displaysPage;
                                default:
                                    return mainPage;
                                }
                            }
                            onSourceComponentChanged: flick.contentY = 0
                            // A destroyed page takes focus with it, and Esc would stop working.
                            onLoaded: (item.wantsFocus ? item : panel).forceActiveFocus()
                        }

                        Connections {
                            target: pageLoader.item
                            ignoreUnknownSignals: true
                            function onScrollToTop() {
                                flick.contentY = 0;
                            }
                        }

                        Rectangle {
                            parent: flick
                            anchors.right: parent.right
                            y: flick.visibleArea.yPosition * flick.height
                            width: 3
                            height: flick.visibleArea.heightRatio * flick.height
                            radius: 2
                            color: Theme.dim
                            visible: flick.contentHeight > flick.height
                        }
                    }
                }

                Component {
                    id: mainPage
                    MainPage {}
                }

                Component {
                    id: audioPage
                    AudioPage {}
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
                    id: displaysPage
                    DisplaysPage {}
                }
            }
        }
    }
}
