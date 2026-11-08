pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    readonly property int maxHistory: 100
    readonly property int maxPopups: 4

    property bool dnd: false

    // Receive times and currently shown toasts, by notification id.
    property var receivedAt: ({})
    property var popupIds: []

    // For relative times; updated only while the panel is open.
    property date now: new Date()

    readonly property var tracked: server.trackedNotifications.values
    readonly property var history: tracked.filter(n => !n.transient).reverse()
    readonly property int count: history.length
    readonly property var popups: tracked.filter(n => popupIds.includes(n.id)).reverse().slice(0, maxPopups)

    /**
     * Records a new notification and shows it unless silenced.
     * @param {Notification} notification  incoming notification
     */
    function handle(notification) {
        notification.tracked = true;

        const times = Object.assign({}, receivedAt);
        times[notification.id] = new Date();
        receivedAt = times;

        const known = tracked.map(n => n.id);
        const active = popupIds.filter(id => known.includes(id));
        const silenced = dnd && notification.urgency !== NotificationUrgency.Critical;
        if (silenced) {
            popupIds = active;
            if (notification.transient) notification.expire();
        } else {
            popupIds = active.includes(notification.id) ? active : [...active, notification.id];
        }
        trimHistory();
    }

    /** Expires notifications beyond the history limit. */
    function trimHistory() {
        const excess = history.slice(maxHistory);
        for (const notification of excess) notification.expire();
    }

    /**
     * Hides a toast. The notification stays in history unless it is transient.
     * @param {Notification} notification  shown notification
     */
    function endPopup(notification) {
        popupIds = popupIds.filter(id => id !== notification.id);
        if (notification.transient) notification.expire();
    }

    /**
     * Returns how long a toast stays visible.
     * @param {Notification} notification  shown notification
     * @returns {int} milliseconds, 0 for no timeout
     */
    function popupTimeout(notification) {
        if (notification.urgency === NotificationUrgency.Critical) return 0;
        // expireTimeout is in milliseconds, and -1 means default.
        const timeout = notification.expireTimeout;
        if (timeout >= 0) return timeout;
        return notification.urgency === NotificationUrgency.Low ? 3000 : 5000;
    }

    /** Dismisses every notification in history. */
    function clearAll() {
        for (const notification of history.slice()) notification.dismiss();
    }

    /**
     * Runs a notification's default action.
     * @param {Notification} notification  target notification
     * @returns {bool} whether one existed
     */
    function invokeDefault(notification) {
        const action = notification.actions.find(a => a.identifier === "default");
        if (action) action.invoke();
        return action !== undefined;
    }

    /**
     * Returns actions to show as buttons. The default action is run by clicking the body.
     * @param {Notification} notification  target notification
     * @returns {list}
     */
    function visibleActions(notification) {
        return notification.actions.filter(a => a.identifier !== "default" && a.text !== "");
    }

    /**
     * Removes specification markup that some senders use without checking support. The result is shown as plain text, so nothing is interpreted.
     * @param {string} text  notification body
     * @returns {string}
     */
    function plainBody(text) {
        return (text ?? "")
            .replace(/<\/?(b|i|u|a|img)(\s[^>]*)?\/?>/gi, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&apos;/g, "'")
            .replace(/&amp;/g, "&");
    }

    /**
     * Returns when a notification arrived, in relative form.
     * @param {Notification} notification  target notification
     * @returns {string}
     */
    function relativeTime(notification) {
        const received = receivedAt[notification.id];
        if (!received) return "";
        const minutes = Math.floor((now - received) / 60000);
        if (minutes < 1) return I18n.t("time.now");
        if (minutes < 60) return I18n.t("time.minutesAgo", { minutes });
        return received.toLocaleString(I18n.locale, "HH:mm");
    }

    /**
     * Finds an image or icon for a notification.
     * @param {Notification} notification  target notification
     * @returns {string} empty when none
     */
    function iconSource(notification) {
        if (notification.image) return notification.image;
        for (const name of [notification.appIcon, notification.desktopEntry]) {
            if (!name) continue;
            if (name.startsWith("/")) return `file://${name}`;
            if (name.includes("://")) return name;
            const path = Quickshell.iconPath(name, true);
            if (path) return path;
        }
        return "";
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        persistenceSupported: true
        // The body is shown as plain text, so markup support is not declared.
        bodyMarkupSupported: false

        onNotification: notification => root.handle(notification)
    }

    Timer {
        interval: 30000
        repeat: true
        running: Panels.actionCenterOpen
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    IpcHandler {
        target: "notifications"

        function describe(): string {
            return JSON.stringify({
                dnd: root.dnd,
                popups: root.popups.map(n => n.id),
                history: root.history.map(n => ({
                    id: n.id,
                    app: n.appName,
                    summary: n.summary,
                    body: n.body,
                    urgency: NotificationUrgency.toString(n.urgency),
                    timeout: n.expireTimeout,
                    transient: n.transient,
                    resident: n.resident,
                    image: String(n.image),
                    icon: root.iconSource(n),
                    actions: n.actions.map(a => a.identifier)
                }))
            });
        }
        function setDnd(value: bool): void { root.dnd = value; }
        function clear(): void { root.clearAll(); }
        function dismiss(id: int): void { root.tracked.find(n => n.id === id)?.dismiss(); }
        function invoke(id: int, identifier: string): bool {
            const action = root.tracked.find(n => n.id === id)?.actions.find(a => a.identifier === identifier);
            action?.invoke();
            return action !== undefined;
        }
    }
}
