pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The one place the shell watches the local system from; services and modules listen through
// EventSubscription and never start a watch of their own, so a change of tool happens here alone.
//
// A source is a named stream, a process that prints a line per event; a file whose changes are watched; or,
// where nothing reports a change, a file read again at an interval.
// Each runs once however many listen: it starts with its first listener and stops after its last. A stream
// ends together with the shell (setpriv --pdeathsig) and starts again if it fails, waiting longer after
// each failure in a row. A stream may depend on another, which restarts it on every event, as the camera
// watch follows cameras being plugged in.
Singleton {
    id: root

    readonly property var streams: ({
            // NetworkManager: connections, devices, Wi-Fi and VPN coming and going.
            network: {
                command: ["env", "LC_ALL=C", "nmcli", "monitor"]
            },
            // UDisks: drives plugged in and out, mounted and unmounted.
            drives: {
                command: ["udisksctl", "monitor"]
            },
            // PulseAudio's interface to PipeWire: outputs, inputs and their ports.
            audio: {
                command: ["env", "LC_ALL=C", "pactl", "subscribe"]
            },
            // Video devices added or removed, such as a USB camera.
            videoDevices: {
                command: ["udevadm", "monitor", "--udev", "--subsystem-match=video4linux"]
            },
            // A camera opened or closed. Browsers open it directly rather than through PipeWire, so the
            // devices are watched; without one the watch waits idle until a camera appears.
            camera: {
                command: ["sh", "-c", "ls /dev/video* >/dev/null 2>&1 || exec sleep infinity; exec inotifywait -m -q -e open -e close --format '%e %f' /dev/video*"],
                restartWith: "videoDevices"
            }
        })

    // Running sources by key ("stream:name", "file:path" or "poll:interval:path"): { object, listeners }.
    property var active: ({})

    /**
     * Adds a listener to its source, starting the source if it is the first.
     * @param {EventSubscription} listener  the subscription, with its key
     */
    function attach(listener) {
        const key = listener.attachedKey;
        let entry = active[key];
        if (!entry) {
            entry = {
                object: start(key),
                listeners: []
            };
            active[key] = entry;
        }
        if (!entry.listeners.includes(listener))
            entry.listeners.push(listener);
    }

    /**
     * Removes a listener, stopping its source after the last.
     * @param {EventSubscription} listener  the subscription
     */
    function detach(listener) {
        const key = listener.attachedKey;
        const entry = active[key];
        if (!entry)
            return;
        entry.listeners = entry.listeners.filter(l => l !== listener);
        if (entry.listeners.length > 0)
            return;
        delete active[key];
        entry.object?.stop();
        entry.object?.destroy();
    }

    /**
     * Starts the source behind a key.
     * @param {string} key  "stream:name", "file:path" or "poll:interval:path"
     * @returns {QtObject} the running source
     */
    function start(key) {
        const [kind, name] = [key.slice(0, key.indexOf(":")), key.slice(key.indexOf(":") + 1)];
        if (kind === "poll") {
            const split = name.indexOf(":");
            return pollSource.createObject(root, {
                key: key,
                interval: Number(name.slice(0, split)),
                path: name.slice(split + 1)
            });
        }
        if (kind === "file")
            return fileSource.createObject(root, {
                key: key,
                path: name
            });
        const spec = streams[name];
        if (!spec) {
            console.warn(log, "no stream named", name);
            return null;
        }
        return streamSource.createObject(root, {
            key: key,
            command: ["setpriv", "--pdeathsig", "TERM", ...spec.command],
            dependsOn: spec.restartWith ?? ""
        });
    }

    /**
     * Passes a stream's line to its listeners.
     * @param {string} key  source key
     * @param {string} line  the line
     */
    function dispatchLine(key, line) {
        for (const listener of active[key]?.listeners ?? [])
            listener.event(line);
    }

    /**
     * Tells a file's listeners it changed, with its contents where read.
     * @param {string} key  source key
     * @param {string} text  the file's contents, or nothing
     */
    function dispatchChange(key, text) {
        for (const listener of active[key]?.listeners ?? []) {
            if (text !== undefined)
                listener.text = text;
            listener.changed();
        }
    }

    component StreamSource: QtObject {
        id: stream

        // The stream it depends on is attached after this one is made: making it from the same template while
        // this one is still being made would fail without a word.
        Component.onCompleted: {
            process.running = true;
            Qt.callLater(() => dependency.stream = stream.dependsOn);
        }
        // A shell reloaded from the repository destroys its sources without ending; their processes go too.
        Component.onDestruction: stop()

        property string key
        property var command: []
        property string dependsOn: ""
        property bool stopped: false
        property bool restarting: false
        // Failures in a row, which lengthen the wait before the next start.
        property int failures: 0

        /** Stops the process for good. */
        function stop() {
            stopped = true;
            retry.stop();
            process.running = false;
        }

        /** Starts the process again, as when what it watches has changed. */
        function restart() {
            retry.stop();
            if (process.running) {
                restarting = true;
                process.running = false;
            }
            Qt.callLater(() => {
                if (!stream.stopped)
                    process.running = true;
            });
        }

        property Process process: Process {
            command: stream.command
            stdout: SplitParser {
                onRead: line => {
                    if (stream.failures > 0)
                        console.info(log, stream.key, "runs again");
                    stream.failures = 0;
                    root.dispatchLine(stream.key, line);
                }
            }
            onExited: {
                if (stream.stopped)
                    return;
                if (stream.restarting) {
                    stream.restarting = false;
                    return;
                }
                // Said once, not again for each start that fails in a row.
                if (stream.failures === 0)
                    console.info(log, stream.key, "ended, starting it again");
                stream.failures++;
                retry.interval = Math.min(60000, 1000 * Math.pow(2, Math.min(stream.failures, 6)));
                retry.restart();
            }
        }

        property Timer retry: Timer {
            onTriggered: {
                if (!stream.stopped)
                    stream.process.running = true;
            }
        }

        // A stream that follows another restarts on each of its events, and passes the event on, as a camera
        // plugged in is itself news to the camera's listeners.
        property EventSubscription dependency: EventSubscription {
            onEvent: line => {
                stream.restart();
                root.dispatchLine(stream.key, line);
            }
        }
    }

    // FileView follows a file that exists, through being replaced, removed and made again, but not one
    // missing when the watch starts: the file's owner makes it first, and a missing one is only reported.
    component FileSource: FileView {
        id: watched

        property string key

        /** Stops watching. */
        function stop() {
            watchChanges = false;
        }

        watchChanges: true
        printErrors: false
        onFileChanged: root.dispatchChange(key)
        onLoadFailed: console.warn(log, "not watching a missing file,", path)
    }

    // Read again at an interval, for counters and the like that report no change. The second read comes
    // sooner, so a value worked out from the difference of two reads, such as CPU load, is soon there.
    component PollSource: QtObject {
        id: poll

        property string key
        property string path
        property int interval

        /** Stops reading. */
        function stop() {
            timer.stop();
        }

        property FileView file: FileView {
            path: poll.path
            printErrors: false
            onLoaded: root.dispatchChange(poll.key, text())
        }

        property Timer timer: Timer {
            interval: Math.min(400, poll.interval)
            repeat: true
            running: true
            onTriggered: {
                interval = poll.interval;
                poll.file.reload();
            }
        }
    }

    IpcHandler {
        target: "eventsources"

        // The running sources and how many listen to each.
        function describe(): string {
            return JSON.stringify(Object.keys(root.active).map(key => ({
                        key: key,
                        listeners: root.active[key].listeners.length
                    })));
        }
    }

    Component {
        id: pollSource
        PollSource {}
    }

    Component {
        id: streamSource
        StreamSource {}
    }

    Component {
        id: fileSource
        FileSource {}
    }

    LoggingCategory {
        id: log
        name: "hyprdora.eventsources"
    }
}
