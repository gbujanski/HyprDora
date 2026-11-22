pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Calendar events of the Nextcloud accounts and of the offline calendar, kept on this computer only, for the
// calendar next to the clock. A helper talks CalDAV and reads the app passwords from the keyring itself, and
// keeps the offline calendar's files. The last results are kept in a cache, so events and reminders of an
// unreachable account still show; adding and deleting there need its server.
Singleton {
    id: root

    readonly property string helper: "/usr/libexec/hyprdora/calendar"
    readonly property string cachePath: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/hyprdora/calendar.json`

    // Accounts for the helper, as { spec, key }: spec is the helper's JSON argument, key the account the
    // helper files calendars under.
    readonly property var accounts: [...OnlineAccounts.accounts.filter(a => a.provider === "nextcloud").map(a => ({
                    spec: JSON.stringify({
                        kind: "nextcloud",
                        server: a.server,
                        login: a.login
                    }),
                    key: `${a.login}@${a.server.replace(/\/+$/, "")}`,
                    server: a.server
                }))]
    readonly property string localSpec: JSON.stringify({
        kind: "local"
    })
    // The offline calendar is always there, so the calendar works without any account.
    readonly property bool enabled: true
    // The calendar new events went to last, offered first in the form.
    property string lastCalendar: ""

    // The visible range and the next days for reminders: { from, to, events }.
    property var month: null
    property var upcoming: null
    // Calendars that accept new events: [{ href, name, color, account }].
    property var calendars: []
    // True when the last read could not reach a server, so cached events are shown.
    property bool offline: false
    // "" when idle, or "create" / "delete" while a change is sent.
    property string busy: ""
    property string error: ""

    readonly property var byDay: {
        const days = {};
        for (const event of month?.events ?? []) {
            // An event belongs to each day it covers; the end of an all-day event is the day after.
            const first = new Date(`${event.start.slice(0, 10)}T00:00`);
            const last = new Date(`${event.end.slice(0, 10)}T00:00`);
            if (event.allDay || event.end.slice(11) === "00:00")
                last.setDate(last.getDate() - 1);
            // Every event shows at least on its first day, even one that ends at midnight.
            const day = first;
            do {
                const k = key(day);
                days[k] = [...(days[k] ?? []), event];
                day.setDate(day.getDate() + 1);
            } while (day <= last)
        }
        return days;
    }

    /**
     * Formats a date as YYYY-MM-DD in local time.
     * @param {date} day  any time on that day
     * @returns {string}
     */
    function key(day) {
        return `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;
    }

    /**
     * Events on a day.
     * @param {date} day  any time on that day
     * @returns {list}
     */
    function on(day) {
        return byDay[key(day)] ?? [];
    }

    /**
     * Describes when an event happens on a day, such as 10:00–11:00, or "all day"; an event that started
     * the day before or ends the day after shows an ellipsis on that side.
     * @param {object} event  event from on()
     * @param {date} day  the day it is shown on
     * @returns {string}
     */
    function when(event, day) {
        if (event.allDay)
            return I18n.t("calendar.allDay");
        const k = key(day);
        const from = event.start.startsWith(k) ? event.start.slice(11, 16) : "…";
        const to = event.end.startsWith(k) ? event.end.slice(11, 16) : "…";
        return `${from}–${to}`;
    }

    /**
     * Arguments naming every account for the helper.
     * @returns {list}
     */
    function accountArgs() {
        return [...accounts.map(a => a.spec), localSpec];
    }

    /**
     * The helper's arguments for one calendar's account: "local", or a Nextcloud server and login.
     * @param {string} calendar  calendar href
     * @returns {list} empty when the calendar is unknown
     */
    function accountOf(calendar) {
        const target = calendars.find(c => c.href === calendar);
        if (target?.account === "local")
            return localSpec;
        return accounts.find(a => a.key === target?.account)?.spec ?? "";
    }

    /**
     * Whether a calendar is the offline one, which has no attendees.
     * @param {string} calendar  calendar href
     * @returns {bool}
     */
    function isLocal(calendar) {
        return calendars.find(c => c.href === calendar)?.account === "local";
    }

    /**
     * The calendar the form offers first: the one used last, or the first.
     * @returns {string} calendar href
     */
    function preferredCalendar() {
        return calendars.some(c => c.href === lastCalendar) ? lastCalendar : (calendars[0]?.href ?? "");
    }

    /**
     * Joins a fresh reply with the cached events of the accounts it could not reach.
     * @param {list} events  events read now
     * @param {list} cached  events read before, for the same range
     * @param {list} failed  accounts not reached, from the helper
     * @returns {list}
     */
    function withUnreachable(events, cached, failed) {
        const lost = new Set(failed.map(f => f.account));
        const keep = new Set(calendars.filter(c => lost.has(c.account)).map(c => c.href));
        return [...events, ...(cached ?? []).filter(e => keep.has(e.calendar))].sort((a, b) => a.start < b.start ? -1 : a.start > b.start ? 1 : 0);
    }

    /**
     * Reads the events from one day up to, but not including, another; cached events show meanwhile.
     * @param {date} from  first day
     * @param {date} to  day after the last
     */
    function load(from, to) {
        if (!enabled)
            return;
        monthReader.range = {
            from: key(from),
            to: key(to)
        };
        monthReader.command = [helper, "events", key(from), key(to), ...accountArgs()];
        monthReader.running = false;
        monthReader.running = true;
    }

    /** Reads the visible range and the next days again, such as when the calendar opens. */
    function refresh() {
        loadUpcoming();
        if (monthReader.range)
            load(new Date(`${monthReader.range.from}T00:00`), new Date(`${monthReader.range.to}T00:00`));
    }

    /**
     * Adds an event.
     * @param {string} calendar  calendar href
     * @param {object} event  { summary, location, start, end, allDay }
     */
    function create(calendar, event) {
        const account = accountOf(calendar);
        if (account === "" || busy !== "")
            return;
        error = "";
        busy = "create";
        lastCalendar = calendar;
        writer.input = JSON.stringify(event);
        writer.command = [helper, "create", account, calendar];
        writer.stdinEnabled = true;
        writer.running = true;
    }

    /**
     * Deletes an event; for a repeating one, either this occurrence or the whole series.
     * @param {object} event  event from on()
     * @param {bool} wholeSeries  for a repeating event, delete every occurrence
     */
    function remove(event, wholeSeries) {
        const account = accountOf(event.calendar);
        if (account === "" || busy !== "")
            return;
        error = "";
        busy = "delete";
        writer.input = "";
        const occurrence = event.recurring && !wholeSeries ? event.occurrence ?? "" : "";
        writer.command = [helper, "delete", account, event.href, event.etag, ...(occurrence ? [occurrence] : [])];
        writer.stdinEnabled = false;
        writer.running = true;
    }

    /** Opens Nextcloud Calendar in the browser, for what the shell does not edit, such as repeating events. */
    function openInNextcloud() {
        const account = accounts.find(a => a.server);
        if (account)
            Quickshell.execDetached(["xdg-open", `${account.server}/apps/calendar/`]);
    }

    /** Writes the cache. */
    function save() {
        cacheFile.setText(JSON.stringify({
            month: month,
            upcoming: upcoming,
            calendars: calendars,
            lastCalendar: lastCalendar
        }));
    }

    /** Reads the next two days for reminders. */
    function loadUpcoming() {
        if (!enabled || upcomingReader.running)
            return;
        const from = new Date();
        from.setHours(0, 0, 0, 0);
        const to = new Date(from);
        to.setDate(to.getDate() + 3);
        upcomingReader.command = [helper, "events", key(from), key(to), ...accountArgs()];
        upcomingReader.running = true;
    }

    // An account signed in or out changes the calendars at once.
    onAccountsChanged: refresh()

    FileView {
        id: cacheFile
        path: root.cachePath
        printErrors: false
        onLoaded: {
            try {
                const cache = JSON.parse(text());
                root.month = root.month ?? cache.month ?? null;
                root.upcoming = root.upcoming ?? cache.upcoming ?? null;
                if (root.calendars.length === 0)
                    root.calendars = cache.calendars ?? [];
                if (root.lastCalendar === "")
                    root.lastCalendar = cache.lastCalendar ?? "";
            } catch (e) {}
        }
    }

    Process {
        id: monthReader

        property var range: null

        stdout: StdioCollector {
            onStreamFinished: {
                let reply;
                try {
                    reply = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.offline = reply.failed.length > 0;
                // A server that could not be reached keeps its cached events and calendars rather than
                // losing them; the rest is replaced.
                const sameRange = root.month?.from === monthReader.range.from && root.month?.to === monthReader.range.to;
                const lost = new Set(reply.failed.map(f => f.account));
                root.month = {
                    from: monthReader.range.from,
                    to: monthReader.range.to,
                    events: root.withUnreachable(reply.events, sameRange ? root.month.events : [], reply.failed)
                };
                root.calendars = [...reply.calendars.filter(c => c.writable), ...root.calendars.filter(c => lost.has(c.account))];
                root.save();
            }
        }
    }

    Process {
        id: upcomingReader

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse(text);
                    root.upcoming = {
                        events: root.withUnreachable(reply.events, root.upcoming?.events, reply.failed)
                    };
                    root.save();
                } catch (e) {}
            }
        }
    }

    Process {
        id: writer

        property string input: ""

        stderr: StdioCollector {
            id: writerErrors
        }

        onStarted: {
            if (input !== "") {
                write(input);
                stdinEnabled = false;
            }
        }

        onExited: exitCode => {
            const action = root.busy;
            root.busy = "";
            if (exitCode === 0) {
                root.refresh();
                root.loadUpcoming();
                return;
            }
            console.warn(log, writerErrors.text.trim());
            root.error = exitCode === 4 ? I18n.t("calendar.error.offline") : exitCode === 3 ? I18n.t("calendar.error.password") : I18n.t(`calendar.error.${action}`);
        }
    }

    // Reminders come from the cache, so they work offline. An alarm fires once, when its time passes.
    property real lastAlarmCheck: Date.now()
    property var fired: ({})

    Timer {
        interval: 30 * 1000
        repeat: true
        running: root.enabled
        onTriggered: {
            const now = Date.now();
            const fired = Object.assign({}, root.fired);
            for (const event of root.upcoming?.events ?? []) {
                const start = new Date(event.allDay ? `${event.start}T09:00` : event.start).getTime();
                for (const minutes of event.alarms ?? []) {
                    const at = start - minutes * 60000;
                    const id = `${event.uid}|${event.start}|${minutes}`;
                    if (at > root.lastAlarmCheck && at <= now && !fired[id]) {
                        fired[id] = true;
                        const when = event.allDay ? I18n.t("calendar.allDay") : minutes === 0 ? I18n.t("calendar.startsNow") : event.start.slice(11, 16);
                        Quickshell.execDetached(["notify-send", `--app-name=${I18n.t("calendar.title")}`, ...Notifications.glyphArgs(Icons.calendar, ""), event.summary, [when, event.location].filter(Boolean).join(" · ")]);
                    }
                }
            }
            root.fired = fired;
            root.lastAlarmCheck = now;
        }
    }

    // The next days are read every five minutes, so a reminder set shortly before is still known in time.
    // Offline too, as local calendars need no network and accounts out of reach keep their last events; the
    // network returning reads them again at once.
    ScheduledTask {
        interval: 5 * 60 * 1000
        enabled: root.enabled
        needsNetwork: false
        onRun: root.loadUpcoming()
    }

    IpcHandler {
        target: "calendar-events"

        function describe(): string {
            return JSON.stringify({
                enabled: root.enabled,
                offline: root.offline,
                calendars: root.calendars,
                month: root.month ? {
                    from: root.month.from,
                    to: root.month.to,
                    count: root.month.events.length
                } : null,
                upcoming: root.upcoming?.events.length ?? 0
            });
        }
    }

    LoggingCategory {
        id: log
        name: "hyprdora.calendar"
    }
}
