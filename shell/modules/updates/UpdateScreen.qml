import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Full screen while updates download before an offline update, held as a session lock, so the desktop, its
// shortcuts and applications are out of reach; only volume, brightness and the power button work. It shows
// how many updates and megabytes have downloaded. Power off now is the only way out while it downloads;
// after a failure, which changed nothing yet, it can also try again or return to the desktop. The progress
// is on the screen that had focus; other screens stay black.
Scope {
    id: root

    property var mainScreen: null
    readonly property var progress: Updates.progress ?? ({})
    readonly property string phase: progress.state ?? "preparing"

    Connections {
        target: Updates
        function onUpdatingChanged() {
            if (Updates.updating)
                root.mainScreen = Panels.focusedScreen();
        }
    }

    // Always present, like the lock screen: a loader going away could drop the lock.
    WlSessionLock {
        locked: Updates.updating

        WlSessionLockSurface {
            id: surface

            color: "black"

            Column {
                id: column

                anchors.centerIn: parent
                width: Math.min(420, parent.width - 64)
                spacing: 14
                visible: surface.screen === root.mainScreen || root.mainScreen === null

                // Turns while anything is under way, so a long wait for the next package does not look frozen.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Spinner {
                        id: busy

                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        color: Theme.accent
                        running: root.phase !== "failed"
                    }

                    Label {
                        width: Math.min(implicitWidth, column.width - (busy.visible ? busy.width + parent.spacing : 0))
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeTitle + 6
                        font.weight: Font.DemiBold
                        text: {
                            switch (root.phase) {
                            case "downloading":
                                return I18n.t("updates.screen.downloading");
                            case "restarting":
                                return I18n.t(root.progress.mode === "poweroff" ? "updates.screen.poweringOff" : "updates.screen.restarting");
                            case "failed":
                                return I18n.t("updates.screen.failed");
                            default:
                                return I18n.t("updates.screen.preparing");
                            }
                        }
                    }
                }

                Meter {
                    width: parent.width
                    implicitHeight: 6
                    visible: root.phase !== "failed"
                    fillColor: Theme.accent
                    value: {
                        const p = root.progress;
                        if (root.phase === "restarting")
                            return 1;
                        if ((p.totalBytes ?? 0) > 0)
                            return p.bytes / p.totalBytes;
                        return (p.total ?? 0) > 0 ? p.done / p.total : 0;
                    }
                }

                // 10/58 · 120 / 450 MB
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.phase === "downloading" && (root.progress.total ?? 0) > 0
                    color: Theme.muted
                    text: {
                        const p = root.progress;
                        const parts = [`${Math.min(p.done ?? 0, p.total ?? 0)}/${p.total ?? 0}`];
                        if ((p.totalBytes ?? 0) > 0)
                            parts.push(`${Updates.formatSize(Math.min(p.bytes, p.totalBytes))} / ${Updates.formatSize(p.totalBytes)}`);
                        return parts.join(" · ");
                    }
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.phase === "failed" && text !== ""
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: Theme.muted
                    text: root.progress.message ?? ""
                }

                Item {
                    width: 1
                    height: 10
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: root.phase === "failed"

                    TextButton {
                        primary: true
                        text: I18n.t("updates.screen.retry")
                        onClicked: Updates.retryOffline()
                    }

                    TextButton {
                        text: I18n.t("updates.screen.poweroff")
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }

                    TextButton {
                        text: I18n.t("updates.screen.back")
                        onClicked: Updates.cancelOffline()
                    }
                }

                // While downloading, powering off is the only way out; the next attempt resumes the download.
                TextButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.phase === "preparing" || root.phase === "downloading"
                    text: I18n.t("updates.screen.poweroffNow")
                    onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
        }
    }
}
