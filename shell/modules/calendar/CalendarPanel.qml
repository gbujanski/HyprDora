import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Calendar with weather below the clock. Like the action center, a click outside
// or Esc closes it, and a closed window does not exist.
Scope {
    id: root


    Connections {
        target: Panels
        function onCalendarOpenChanged() {
            if (Panels.calendarOpen) Weather.refreshIfStale();
            else closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.calendarOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.calendarOpen

            Component.onCompleted: entered = true

            screen: Panels.calendarScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-calendar"
            // OnDemand, not Exclusive: with Exclusive, Hyprland routes all clicks to this layer
            // and the bar stops reacting. Focus still reaches the panel on open, so Esc works.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeCalendar()
            }

            Rectangle {
                id: panel

                property int year: clock.date.getFullYear()
                property int month: clock.date.getMonth()
                readonly property bool isCurrentMonth: year === clock.date.getFullYear() && month === clock.date.getMonth()

                function shiftMonth(delta) {
                    const d = new Date(year, month + delta, 1);
                    year = d.getFullYear();
                    month = d.getMonth();
                }

                function showToday() {
                    year = clock.date.getFullYear();
                    month = clock.date.getMonth();
                }

                Component.onCompleted: {
                    // Breaks the bindings: from here on only the buttons drive it.
                    year = clock.date.getFullYear();
                    month = clock.date.getMonth();
                    forceActiveFocus();
                }

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: Theme.panelMargin
                }
                width: 320
                height: content.implicitHeight + Theme.panelPadding * 2
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                transform: Translate {
                    y: window.shown ? 0 : -12
                    Behavior on y { NumberAnimation { duration: Theme.animPanel; easing.type: Easing.OutCubic } }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.animPanel } }

                Keys.onEscapePressed: Panels.closeCalendar()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) panel.shiftMonth(-1);
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) panel.shiftMonth(1);
                    else if (event.key === Qt.Key_Home) panel.showToday();
                    else return;
                    event.accepted = true;
                }

                // Absorbs clicks so they do not reach the closing area.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    // A touchpad sends dozens of events per gesture, so month changes have a minimum delay.
                    // Longer scrolling moves through months at a pace that can be followed.
                    property real lastStep: 0

                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y;
                        if (delta === 0) return;
                        const now = Date.now();
                        if (now - lastStep < Settings.calendarScrollDelay) return;
                        lastStep = now;
                        panel.shiftMonth(delta > 0 ? -1 : 1);
                    }
                }

                Column {
                    id: content

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    spacing: 10

                    Column {
                        spacing: 1

                        Label {
                            text: clock.date.toLocaleDateString(I18n.locale, "dddd")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            text: clock.date.toLocaleDateString(I18n.locale, "d MMMM yyyy")
                            font.pixelSize: Theme.fontSizeTitle + 3
                            font.weight: Font.DemiBold
                        }
                    }

                    Item {
                        width: parent.width
                        height: 30

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 4
                            text: `${I18n.monthName(panel.month)} ${panel.year}`
                            font.weight: Font.Medium
                        }

                        Row {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !panel.isCurrentMonth
                                implicitHeight: 26
                                text: I18n.t("calendar.today")
                                onClicked: panel.showToday()
                            }

                            IconButton {
                                icon: Icons.chevronLeft
                                iconColor: Theme.muted
                                tooltip: I18n.t("calendar.previousMonth")
                                onClicked: panel.shiftMonth(-1)
                            }

                            IconButton {
                                icon: Icons.chevronRight
                                iconColor: Theme.muted
                                tooltip: I18n.t("calendar.nextMonth")
                                onClicked: panel.shiftMonth(1)
                            }
                        }
                    }

                    MonthGrid {
                        width: parent.width
                        year: panel.year
                        month: panel.month
                        today: clock.date
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.surface
                    }

                    WeatherDetails {
                        width: parent.width
                    }
                }
            }
        }
    }
}
