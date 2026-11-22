pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.base
import qs.config

// Removable drives (USB sticks, SD cards, USB disks) and their partitions, as UDisks sees them. Removing a
// drive safely unmounts its filesystems and locks its unlocked encrypted partitions, then ejects a card
// from its reader and powers any other drive off, as on Windows. Powering off a card reader would cut off
// the reader itself, which in a laptop stays cut off until the next start. When a drive is in use, the
// programs holding it are named with what they do there. Those that only read a file there and write
// nowhere can be closed, so the drive comes free; one that writes is never closed, as it would leave a file
// cut short that looks whole. An encrypted partition, such as BitLocker's, is unlocked with its password,
// which goes to udisksctl on its standard input, never on a command line other processes can read.
Singleton {
    id: root

    // [{ id, title, size, icon, disk, mediaRemovable, canPowerOff, volumes }], in the order UDisks lists
    // them. A volume: { device, label, size, encrypted, unlocked, mountDevice, mountPoints }; mountDevice is
    // the partition itself, or for an unlocked encrypted one the device that holds its unlocked contents.
    property var drives: []
    // What removing a drive came to, by its id: { state: "removing" | "busy" | "failed", holders, closable,
    // message }. A holder: { name, reason: "writes" | "runs" | "folder" | "reads" | "uses" }; closable when
    // every holder may be closed.
    property var status: ({})
    // What unlocking a volume came to, by its device: { state: "unlocking" | "failed", message }.
    property var unlockStatus: ({})

    // The drive being removed, the commands left to run for it, and the mount points to check when busy.
    property var current: null
    property var steps: []
    property var mountPoints: []
    // Whether the programs holding the current drive are closed when they may be.
    property bool closing: false

    /** Reads the drives again. */
    function refresh() {
        if (!dump.running)
            dump.running = true;
    }

    /**
     * Turns `udisksctl dump` into objects by path, each holding its interfaces' properties.
     * @param {string} text  output of udisksctl dump
     * @returns {object} { path: { interface: { key: value } } }
     */
    function parseDump(text) {
        const objects = {};
        let object = null;
        let iface = null;
        let key = null;
        for (const line of text.split("\n")) {
            let m;
            if ((m = /^(\/org\/\S+):$/.exec(line))) {
                object = objects[m[1]] = {};
                iface = key = null;
            } else if (object && (m = /^ {2}(org\.[\w.]+):$/.exec(line))) {
                iface = object[m[1].replace("org.freedesktop.UDisks2.", "")] = {};
                key = null;
            } else if (iface && (m = /^ {4}(\w+):\s*(.*)$/.exec(line))) {
                key = m[1];
                iface[key] = m[2].replace(/^'(.*)'$/, "$1");
            } else if (iface && key && line.trim() !== "") {
                // A list goes on over the following lines, such as several mount points.
                iface[key] += "\n" + line.trim();
            }
        }
        return objects;
    }

    /**
     * Returns a block's mount points.
     * @param {object} object  UDisks object
     * @returns {array} paths
     */
    function mountPointsOf(object) {
        return (object?.Filesystem?.MountPoints ?? "").split("\n").filter(p => p !== "");
    }

    /**
     * Picks the removable drives and their volumes out of the objects.
     * @param {object} objects  result of parseDump
     * @returns {array} drives
     */
    function removableDrives(objects) {
        const result = [];
        const entries = Object.entries(objects);
        for (const [path, object] of entries) {
            const block = object.Block;
            // Whole disks only; their partitions are gathered below.
            if (!block || object.Partition || block.CryptoBackingDevice !== "/" || block.Drive === "/" || block.HintSystem === "true" || block.HintIgnore === "true")
                continue;
            const drive = objects[block.Drive]?.Drive;
            if (!drive || Number(block.Size) <= 0)
                continue;
            if (!(drive.ConnectionBus === "usb" || drive.ConnectionBus === "sdio" || drive.Removable === "true"))
                continue;
            // A disk with a filesystem straight on it is its own single volume.
            const parts = entries.filter(([, o]) => o.Partition?.Table === path);
            const candidates = object.Filesystem || object.Encrypted ? [[path, object]] : parts;
            const volumes = candidates.filter(([, o]) => o.Filesystem || o.Encrypted).map(([partPath, o]) => {
                const cleartextPath = o.Encrypted?.CleartextDevice ?? "/";
                const cleartext = cleartextPath !== "/" ? objects[cleartextPath] : null;
                const holder = cleartext ?? o;
                return {
                    device: o.Block.Device,
                    label: o.Block.IdLabel || o.Partition?.Name || "",
                    size: Number(o.Block.Size),
                    encrypted: !!o.Encrypted,
                    unlocked: !!cleartext,
                    mountDevice: holder.Block.Device,
                    mountPoints: mountPointsOf(holder)
                };
            });
            const card = drive.MediaRemovable === "true";
            result.push({
                id: block.Drive,
                title: [drive.Vendor, drive.Model].map(s => (s ?? "").trim()).filter(s => s).join(" ") || block.Device,
                size: Number(block.Size),
                icon: card ? Icons.sdCard : Icons.usbDrive,
                disk: block.Device,
                mediaRemovable: card,
                canPowerOff: drive.CanPowerOff === "true",
                volumes: volumes
            });
        }
        return result;
    }

    /**
     * Sets or clears an entry of a status map.
     * @param {string} name  "status" or "unlockStatus"
     * @param {string} key  drive id or volume device
     * @param {object} value  status, or null to clear it
     */
    function setEntry(name, key, value) {
        const next = Object.assign({}, root[name]);
        if (value)
            next[key] = value;
        else
            delete next[key];
        root[name] = next;
    }

    /**
     * Sorts out what each process holding a drive does there, from the lines of the holders command, and
     * gathers them by application.
     * @param {string} text  lines "pid comm|cwd|exe value" and "pid fd flags target"
     * @param {array} points  the drive's mount points
     * @returns {object} { holders: [{ name, reason }], closable, pids }
     */
    function holdersOf(text, points) {
        const on = path => points.some(p => path === p || path.startsWith(p + "/"));
        // A regular file, not a device, a pipe, a socket or memory.
        const isFile = path => path.startsWith("/") && !/^\/(dev|proc|sys|memfd:)/.test(path);
        const processes = {};
        for (const line of text.split("\n")) {
            const m = /^(\d+) (comm|cwd|exe|fd) (.*)$/.exec(line);
            if (!m)
                continue;
            const p = processes[m[1]] ?? (processes[m[1]] = {
                    name: "",
                    writesHere: false,
                    writesElsewhere: false,
                    readsHere: false,
                    folder: false,
                    runs: false
                });
            if (m[2] === "comm")
                p.name = m[3];
            else if (m[2] === "cwd")
                p.folder = on(m[3]);
            else if (m[2] === "exe")
                p.runs = on(m[3]);
            else {
                const fd = /^([0-7]+) (.*)$/.exec(m[3]);
                if (!fd || !isFile(fd[2]))
                    continue;
                // The access mode is the lowest two bits: 0 read only, 1 write only, 2 both.
                const writes = (parseInt(fd[1], 8) & 3) !== 0;
                if (on(fd[2])) {
                    p.writesHere = p.writesHere || writes;
                    p.readsHere = p.readsHere || !writes;
                } else if (writes) {
                    p.writesElsewhere = true;
                }
            }
        }
        const order = ["writes", "runs", "folder", "reads", "uses"];
        const byName = {};
        const list = [];
        const pids = [];
        let closable = true;
        for (const [pid, p] of Object.entries(processes)) {
            // One whose files cannot be read, as another user's, is only known to use the drive.
            const reason = p.writesHere ? "writes" : p.runs ? "runs" : p.folder ? "folder" : p.readsHere ? "reads" : "uses";
            // Closing one that writes anywhere, such as a copy from the drive, would cut that file short.
            if (reason !== "reads" || p.writesElsewhere)
                closable = false;
            pids.push(pid);
            const name = DesktopEntries.heuristicLookup(p.name)?.name ?? (p.name || pid);
            const holder = byName[name];
            if (!holder) {
                byName[name] = {
                    name: name,
                    reason: reason
                };
                list.push(byName[name]);
            } else if (order.indexOf(reason) < order.indexOf(holder.reason)) {
                holder.reason = reason;
            }
        }
        return {
            holders: list,
            closable: closable && list.length > 0,
            pids: pids
        };
    }

    /**
     * Removes a drive safely: unmounts its filesystems, locks its unlocked encrypted partitions, then
     * ejects the card or powers the drive off.
     * @param {object} given  entry of drives, as a view passes it
     * @param {bool} close  whether to close the programs holding it, when they may be closed
     */
    function remove(given, close) {
        // The service's own entry: one passed through a view's model has its lists turned into Qt's, which
        // lack some of JavaScript's array methods.
        const drive = drives.find(d => d.id === given.id);
        if (current || !drive)
            return;
        const volumes = Array.from(drive.volumes);
        const commands = volumes.filter(v => v.mountPoints.length > 0).map(v => ["udisksctl", "unmount", "--no-user-interaction", "-b", v.mountDevice]);
        for (const volume of volumes.filter(v => v.unlocked))
            commands.push(["udisksctl", "lock", "--no-user-interaction", "-b", volume.device]);
        if (drive.mediaRemovable)
            commands.push(["gdbus", "call", "--system", "--dest", "org.freedesktop.UDisks2", "--object-path", drive.id, "--method", "org.freedesktop.UDisks2.Drive.Eject", "{}"]);
        else if (drive.canPowerOff)
            commands.push(["udisksctl", "power-off", "--no-user-interaction", "-b", drive.disk]);
        // Qt's JavaScript engine has no flatMap.
        mountPoints = volumes.reduce((all, v) => all.concat(Array.from(v.mountPoints)), []);
        steps = commands;
        current = drive;
        closing = close === true;
        setEntry("status", drive.id, {
            state: "removing"
        });
        nextStep();
    }

    /** Runs the next command of the current removal, or finishes it. */
    function nextStep() {
        if (steps.length === 0) {
            Quickshell.execDetached(["notify-send", "--transient", `--app-name=${I18n.t("drives.appName")}`, ...Notifications.glyphArgs(Icons.eject, ""), I18n.t("drives.removed", {
                    name: current.title
                })]);
            setEntry("status", current.id, null);
            current = null;
            refresh();
            return;
        }
        step.command = steps[0];
        steps = steps.slice(1);
        step.running = true;
    }

    /**
     * Opens a volume in the file manager, mounting it first if needed. A locked encrypted volume is
     * unlocked first, with unlock().
     * @param {object} volume  entry of a drive's volumes
     */
    function open(volume) {
        if (volume.mountPoints.length > 0) {
            Quickshell.execDetached(["gio", "open", volume.mountPoints[0]]);
            return;
        }
        if (volume.encrypted && !volume.unlocked)
            return;
        mounter.command = ["udisksctl", "mount", "--no-user-interaction", "-b", volume.mountDevice];
        mounter.running = true;
    }

    /**
     * Unlocks an encrypted volume with its password, then mounts and opens it.
     * @param {object} volume  entry of a drive's volumes
     * @param {string} password  the volume's password
     */
    function unlock(volume, password) {
        if (unlocker.running)
            return;
        unlocker.device = volume.device;
        unlocker.password = password;
        setEntry("unlockStatus", volume.device, {
            state: "unlocking"
        });
        unlocker.running = true;
    }

    IpcHandler {
        target: "drives"

        function describe(): string {
            return JSON.stringify({
                drives: root.drives.map(d => ({
                            id: d.id,
                            title: d.title,
                            volumes: Array.from(d.volumes).map(v => ({
                                        device: v.device,
                                        label: v.label,
                                        encrypted: v.encrypted,
                                        unlocked: v.unlocked,
                                        mountPoints: Array.from(v.mountPoints)
                                    }))
                        })),
                status: root.status,
                removing: root.current?.id ?? ""
            });
        }
        // Removes the drive with the given UDisks id, as its button does.
        function remove(id: string): bool {
            const drive = root.drives.find(d => d.id === id);
            if (drive)
                root.remove(drive);
            return drive !== undefined;
        }
        // Closes the programs holding the drive, when they may be closed, and removes it, as its button does.
        function closeAndRemove(id: string): bool {
            const drive = root.drives.find(d => d.id === id);
            if (drive)
                root.remove(drive, true);
            return drive !== undefined;
        }
    }

    Process {
        id: dump
        command: ["udisksctl", "dump"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.drives = root.removableDrives(root.parseDump(text));
                // A drive taken out, even while its removal failed, leaves no status behind.
                const ids = root.drives.map(d => d.id);
                if (Object.keys(root.status).some(id => !ids.includes(id) && id !== root.current?.id))
                    // Qt's JavaScript engine has no Object.fromEntries.
                    root.status = Object.keys(root.status).filter(id => ids.includes(id)).reduce((kept, id) => Object.assign(kept, {
                            [id]: root.status[id]
                        }), {});
            }
        }
    }

    // Any change UDisks sees, including a drive mounted by the file manager, reads the drives again.
    EventSubscription {
        stream: "drives"
        onEvent: refreshDelay.restart()
    }

    Timer {
        id: refreshDelay
        interval: 300
        onTriggered: root.refresh()
    }

    Process {
        id: step
        stderr: StdioCollector {
            id: stepErrors
        }
        onExited: code => {
            if (code === 0) {
                // The process counts as running until this handler returns, so the next one starts after it.
                Qt.callLater(root.nextStep);
                return;
            }
            const message = stepErrors.text.trim();
            root.steps = [];
            if (/busy/i.test(message) && root.mountPoints.length > 0) {
                users.command = ["fuser", "-m", ...Array.from(root.mountPoints)];
                Qt.callLater(() => users.running = true);
            } else {
                root.setEntry("status", root.current.id, {
                    state: "failed",
                    message: message.split("\n").pop()
                });
                root.current = null;
                root.refresh();
            }
        }
    }

    // The processes using a busy drive.
    Process {
        id: users
        stdout: StdioCollector {
            onStreamFinished: {
                const pids = text.trim().split(/\s+/).filter(p => /^\d+$/.test(p));
                if (pids.length === 0) {
                    holders.finish({
                        holders: [],
                        closable: false,
                        pids: []
                    });
                    return;
                }
                holders.command = ["sh", "-c", holders.script, "sh", ...pids];
                holders.running = true;
            }
        }
    }

    // What each of them does on the drive: its name, its folder and program, and each open file with the
    // flags it was opened with, which tell reading from writing. holdersOf() sorts the lines out.
    Process {
        id: holders

        readonly property string script: 'for p; do printf "%s comm %s\\n" "$p" "$(cat /proc/$p/comm)"; printf "%s cwd %s\\n" "$p" "$(readlink /proc/$p/cwd)"; printf "%s exe %s\\n" "$p" "$(readlink /proc/$p/exe)"; for f in /proc/$p/fd/*; do printf "%s fd %s %s\\n" "$p" "$(sed -n "s/^flags:\\s*//p" /proc/$p/fdinfo/${f##*/})" "$(readlink "$f")"; done; done 2>/dev/null'

        /**
         * Ends a removal that found the drive busy, or closes the programs holding it and tries once more.
         * @param {object} found  result of holdersOf
         */
        function finish(found) {
            const drive = root.current;
            if (root.closing && found.closable) {
                closer.driveId = drive.id;
                closer.command = ["kill", "-TERM", ...found.pids];
                closer.running = true;
            } else {
                root.setEntry("status", drive.id, {
                    state: "busy",
                    holders: found.holders,
                    closable: found.closable
                });
            }
            root.current = null;
            root.closing = false;
            root.refresh();
        }

        stdout: StdioCollector {
            onStreamFinished: holders.finish(root.holdersOf(text, Array.from(root.mountPoints)))
        }
    }

    // Asks the programs that only read from the drive to end, as a logout does, then tries the removal again;
    // one still running leaves the drive busy and is named again.
    Process {
        id: closer

        property string driveId: ""

        onExited: retryAfterClose.restart()
    }

    // A program asked to end takes a moment to close its files.
    Timer {
        id: retryAfterClose
        interval: 1000
        onTriggered: {
            const drive = root.drives.find(d => d.id === closer.driveId);
            if (drive)
                root.remove(drive);
        }
    }

    // Unlocks with the password written to its standard input, then mounts the unlocked contents.
    Process {
        id: unlocker

        property string device: ""
        property string password: ""

        command: ["udisksctl", "unlock", "--no-user-interaction", "-b", device, "--key-file", "/dev/stdin"]
        stdinEnabled: true
        onStarted: {
            write(password);
            password = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            id: unlockOutput
        }
        stderr: StdioCollector {
            id: unlockErrors
        }
        onExited: code => {
            const cleartext = /as (\/dev\/\S+?)\.?$/.exec(unlockOutput.text.trim())?.[1];
            if (code === 0 && cleartext) {
                root.setEntry("unlockStatus", device, null);
                mounter.command = ["udisksctl", "mount", "--no-user-interaction", "-b", cleartext];
                Qt.callLater(() => mounter.running = true);
            } else {
                root.setEntry("unlockStatus", device, {
                    state: "failed",
                    message: unlockErrors.text.trim().split("\n").pop()
                });
            }
            stdinEnabled = true;
            root.refresh();
        }
    }

    // The file manager opens a volume once it is mounted.
    Process {
        id: mounter
        stdout: StdioCollector {
            onStreamFinished: {
                const point = / at (.+?)\.?$/.exec(text.trim())?.[1];
                if (point)
                    Quickshell.execDetached(["gio", "open", point]);
            }
        }
        onExited: root.refresh()
    }
}
