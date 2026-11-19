pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notifications: toasts and the history in the action center. The history is also saved, so it comes back
// after the shell restarts, after logging out and after a restart of the computer, for 7 days. A saved
// entry keeps its application's icon, and a click opens the application; actions and pictures belong to
// the program that sent it and do not come back. The file is in a directory only its owner may open.
Singleton {
    id: root

    readonly property int maxHistory: 100
    readonly property int maxPopups: 4
    readonly property real keepFor: 7 * 24 * 3600 * 1000
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/hyprdora`
    // Hint on notifications that are not worth keeping past this session, such as a screenshot's preview.
    readonly property string sessionOnlyHint: "x-hyprdora-session-only"

    // Saved entries, oldest first: { key, time, appName, summary, body, urgency, desktopEntry, appIcon }.
    property var saved: []
    // The saved entry of each notification received in this session, by notification id.
    property var keys: ({})
    property bool savedLoaded: false

    property bool dnd: false

    // Receive times and currently shown toasts, by notification id.
    property var receivedAt: ({})
    property var popupIds: []

    // For relative times; updated only while the panel is open.
    property date now: new Date()

    // Hint set by the shell's own warnings that must show during Do Not Disturb.
    readonly property string ignoreDndHint: "x-hyprdora-ignore-dnd"

    readonly property var tracked: server.trackedNotifications.values
    readonly property var live: tracked.filter(n => !n.transient).reverse()
    // Entries saved in an earlier session, shown like notifications: no actions, dismissed from the file.
    readonly property var archived: {
        const liveKeys = new Set(tracked.map(n => keys[n.id]).filter(Boolean));
        return saved.filter(e => !liveKeys.has(e.key)).reverse().map(e => ({
                    archived: true,
                    key: e.key,
                    id: -1,
                    time: e.time,
                    appName: e.appName,
                    summary: e.summary,
                    body: e.body,
                    urgency: e.urgency,
                    desktopEntry: e.desktopEntry,
                    appIcon: e.appIcon,
                    image: "",
                    actions: [],
                    dismiss: () => root.forget(e.key)
                }));
    }
    readonly property var history: [...live, ...archived]
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
        remember(notification);

        const known = tracked.map(n => n.id);
        const active = popupIds.filter(id => known.includes(id));
        const silenced = dnd && notification.urgency !== NotificationUrgency.Critical && notification.hints[ignoreDndHint] !== true;
        if (silenced) {
            popupIds = active;
            if (notification.transient)
                notification.expire();
        } else {
            popupIds = active.includes(notification.id) ? active : [...active, notification.id];
        }
        trimHistory();
    }

    /** Expires notifications beyond the history limit, and drops saved entries past it or too old. */
    function trimHistory() {
        const excess = live.slice(maxHistory);
        for (const notification of excess)
            notification.expire();
        const oldest = Date.now() - keepFor;
        const kept = saved.filter(e => e.time >= oldest).slice(-maxHistory);
        if (kept.length !== saved.length) {
            saved = kept;
            writeSaved();
        }
    }

    /**
     * Saves a notification for later sessions and keeps its entry in step with it: changed by its
     * application, or gone from the history, when its entry goes too.
     * @param {Notification} notification  incoming notification
     */
    function remember(notification) {
        if (notification.transient || notification.hints[sessionOnlyHint] === true || !savedLoaded)
            return;
        const key = `${Date.now()}-${notification.id}`;
        keys = Object.assign({}, keys, {
            [notification.id]: key
        });
        saved = [...saved, entryOf(notification, key)];
        writeSaved();
        const update = () => {
            saved = saved.map(e => e.key === key ? entryOf(notification, key, e.time) : e);
            writeSaved();
        };
        notification.summaryChanged.connect(update);
        notification.bodyChanged.connect(update);
        notification.closed.connect(() => root.forget(key));
    }

    /**
     * The saved form of a notification.
     * @param {Notification} notification  source
     * @param {string} key  entry key
     * @param {real} time  when it arrived, in milliseconds; now when left out
     * @returns {object}
     */
    function entryOf(notification, key, time) {
        return {
            key: key,
            time: time ?? Date.now(),
            appName: notification.appName,
            summary: notification.summary,
            body: notification.body,
            urgency: notification.urgency,
            desktopEntry: notification.desktopEntry,
            // A picture sent with the notification itself lives only as long as it does.
            appIcon: notification.appIcon.startsWith("image://") ? "" : notification.appIcon
        };
    }

    /**
     * Drops a saved entry.
     * @param {string} key  entry key
     */
    function forget(key) {
        if (!saved.some(e => e.key === key))
            return;
        saved = saved.filter(e => e.key !== key);
        writeSaved();
    }

    function writeSaved() {
        if (savedLoaded)
            savedFile.setText(JSON.stringify(saved));
    }

    /**
     * Hides a toast. The notification stays in history unless it is transient.
     * @param {Notification} notification  shown notification
     */
    function endPopup(notification) {
        popupIds = popupIds.filter(id => id !== notification.id);
        if (notification.transient)
            notification.expire();
    }

    /**
     * Returns how long a toast stays visible.
     * @param {Notification} notification  shown notification
     * @returns {int} milliseconds, 0 for no timeout
     */
    function popupTimeout(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        // expireTimeout is in milliseconds, and -1 means default.
        const timeout = notification.expireTimeout;
        if (timeout >= 0)
            return timeout;
        return notification.urgency === NotificationUrgency.Low ? 3000 : 5000;
    }

    /** Dismisses every notification in history, saved ones included. */
    function clearAll() {
        for (const notification of live.slice())
            notification.dismiss();
        saved = [];
        writeSaved();
    }

    /**
     * Runs a notification's default action.
     * @param {Notification} notification  target notification
     * @returns {bool} whether one existed
     */
    function invokeDefault(notification) {
        const action = notification.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        return action !== undefined;
    }

    /**
     * Opens the application that sent a notification, as GNOME does when a notification has no default
     * action: such as the Nextcloud client, whose summary of new notifications carries no text or action,
     * with the details in its own window. An application that already runs shows its window.
     * @param {Notification} notification  target notification
     * @returns {bool} whether the application was found
     */
    function openSender(notification) {
        const id = (notification.desktopEntry || DesktopEntries.heuristicLookup(notification.appName)?.id || "").replace(/\.desktop$/, "");
        if (id === "" || !DesktopEntries.byId(id))
            return false;
        Launcher.exec(`gtk-launch ${Launcher.quoted(id)}`);
        return true;
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
        return (text ?? "").replace(/<\/?(b|i|u|a|img)(\s[^>]*)?\/?>/gi, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&");
    }

    /**
     * Returns when a notification arrived, in relative form.
     * @param {Notification} notification  target notification
     * @returns {string}
     */
    function relativeTime(notification) {
        const received = notification.archived ? new Date(notification.time) : receivedAt[notification.id];
        if (!received)
            return "";
        const minutes = Math.floor((now - received) / 60000);
        if (minutes < 1)
            return I18n.t("time.now");
        if (minutes < 60)
            return I18n.t("time.minutesAgo", {
                minutes
            });
        // Earlier days show the day too, such as "pt. 14:05".
        if (received.toDateString() !== now.toDateString())
            return received.toLocaleString(I18n.locale, "ddd HH:mm");
        return received.toLocaleString(I18n.locale, "HH:mm");
    }

    /**
     * Finds an image or icon for a notification.
     * @param {Notification} notification  target notification
     * @returns {string} empty when none
     */
    function iconSource(notification) {
        if (notification.image)
            return notification.image;
        for (const name of [notification.appIcon, notification.desktopEntry]) {
            if (!name)
                continue;
            if (name.startsWith("/"))
                return `file://${name}`;
            if (name.includes("://"))
                return name;
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
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

    // Times are shown only in the notification panel; toasts leave them out.
    Timer {
        interval: 30000
        repeat: true
        running: Panels.isOpen("notifications")
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // The directory first becomes private, so the history file is never readable by others, even for a moment.
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1"', "hyprdora-state", root.stateDir]
        onExited: savedFile.path = `${root.stateDir}/notifications.json`
    }

    FileView {
        id: savedFile

        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                root.saved = Array.isArray(list) ? list.filter(e => e && typeof e.key === "string") : [];
            } catch (e) {
                root.saved = [];
            }
            root.savedLoaded = true;
            root.trimHistory();
        }
        onLoadFailed: root.savedLoaded = true
    }

    // Saved entries age out while the shell runs, too.
    Timer {
        interval: 3600 * 1000
        repeat: true
        running: root.savedLoaded
        onTriggered: root.trimHistory()
    }

    IpcHandler {
        target: "notifications"

        function describe(): string {
            return JSON.stringify({
                dnd: root.dnd,
                popups: root.popups.map(n => n.id),
                history: root.history.map(n => ({
                            archived: n.archived === true,
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
        function setDnd(value: bool): void {
            root.dnd = value;
        }
        function clear(): void {
            root.clearAll();
        }
        function dismiss(id: int): void {
            root.tracked.find(n => n.id === id)?.dismiss();
        }
        function invoke(id: int, identifier: string): bool {
            const action = root.tracked.find(n => n.id === id)?.actions.find(a => a.identifier === identifier);
            action?.invoke();
            return action !== undefined;
        }
    }
}
