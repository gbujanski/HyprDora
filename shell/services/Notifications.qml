pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property int maxHistory: 100
    readonly property int maxPopups: 4

    property bool dnd: false

    // Czas otrzymania i aktualnie pokazywane toasty, po identyfikatorze powiadomienia.
    property var receivedAt: ({})
    property var popupIds: []

    // Do opisu „5 min temu”; odświeżane tylko przy otwartym panelu.
    property date now: new Date()

    readonly property var tracked: server.trackedNotifications.values
    readonly property var history: tracked.filter(n => !n.transient).reverse()
    readonly property int count: history.length
    readonly property var popups: tracked.filter(n => popupIds.includes(n.id)).reverse().slice(0, maxPopups)

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

    function trimHistory() {
        const excess = history.slice(maxHistory);
        for (const notification of excess) notification.expire();
    }

    // Toast znika, ale powiadomienie zostaje w historii. Powiadomienia ulotne nie trafiają tam wcale.
    function endPopup(notification) {
        popupIds = popupIds.filter(id => id !== notification.id);
        if (notification.transient) notification.expire();
    }

    // Czas toastu w ms; 0 oznacza brak automatycznego zamknięcia.
    function popupTimeout(notification) {
        if (notification.urgency === NotificationUrgency.Critical) return 0;
        // expireTimeout jest w milisekundach, a -1 oznacza „domyślnie”.
        const timeout = notification.expireTimeout;
        if (timeout >= 0) return timeout;
        return notification.urgency === NotificationUrgency.Low ? 3000 : 5000;
    }

    function clearAll() {
        for (const notification of history.slice()) notification.dismiss();
    }

    function invokeDefault(notification) {
        const action = notification.actions.find(a => a.identifier === "default");
        if (action) action.invoke();
        return action !== undefined;
    }

    // Akcje do pokazania jako przyciski. „default” obsługuje kliknięcie w treść.
    function visibleActions(notification) {
        return notification.actions.filter(a => a.identifier !== "default" && a.text !== "");
    }

    // Niektórzy nadawcy wysyłają znaczniki mimo braku deklaracji ich obsługi. Usuwamy tylko
    // znaczniki ze specyfikacji i wyświetlamy zwykły tekst, więc nic nie jest interpretowane.
    function plainBody(text) {
        return (text ?? "")
            .replace(/<\/?(b|i|u|a|img)(\s[^>]*)?\/?>/gi, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&apos;/g, "'")
            .replace(/&amp;/g, "&");
    }

    function relativeTime(notification) {
        const received = receivedAt[notification.id];
        if (!received) return "";
        const minutes = Math.floor((now - received) / 60000);
        if (minutes < 1) return "teraz";
        if (minutes < 60) return `${minutes} min temu`;
        return received.toLocaleString(Qt.locale(), "HH:mm");
    }

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
        // Treść jest pokazywana jako zwykły tekst, więc nie deklarujemy obsługi znaczników.
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
