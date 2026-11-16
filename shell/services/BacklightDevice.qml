import QtQuick
import Quickshell
import Quickshell.Io

// One backlight device driven by brightnessctl.
// Level 0..1 is on a perceptual scale (power = p^exponent, p^3 for screens as in CIE L*),
// and 0 means minimumFraction of power rather than an unlit screen.
// The slider, OSD and keys (IPC) share this scale.
Scope {
    id: root

    property string deviceClass: "backlight"
    property string nameContains: ""
    property real exponent: 1
    // Lowest power, as a fraction of maximum, that corresponds to level 0.
    property real minimumFraction: 0

    property string device: ""
    property int maxRaw: 0
    property int raw: 0
    property int pendingRaw: -1
    // The value last set with quiet, such as by dimming when idle; -1 after any other change. The brightness
    // indicator does not show for it.
    property int quietRaw: -1

    readonly property bool available: device !== "" && maxRaw > 0
    readonly property real floorPerceived: Math.pow(minimumFraction, 1 / exponent)
    // A value below the minimum, for example set outside the shell, shows as 0.
    readonly property real level: available ? Math.max(0, Math.min(1, (Math.pow(raw / maxRaw, 1 / exponent) - floorPerceived) / (1 - floorPerceived))) : 0

    /**
     * Converts a level to a raw device value, never below the floor.
     * @param {real} value  level, 0..1
     * @returns {int}
     */
    function rawFor(value) {
        const clamped = Math.max(0, Math.min(1, value));
        const perceived = floorPerceived + (1 - floorPerceived) * clamped;
        const minimumRaw = minimumFraction > 0 ? Math.max(1, Math.round(minimumFraction * maxRaw)) : 0;
        return Math.max(minimumRaw, Math.round(Math.pow(perceived, exponent) * maxRaw));
    }

    /**
     * Sets the device to a level.
     * @param {real} value  level, 0..1
     * @param {bool} quiet  without the brightness indicator, for changes the user did not make
     */
    function setLevel(value, quiet) {
        if (!available)
            return;
        pendingRaw = rawFor(value);
        quietRaw = quiet ? pendingRaw : -1;
        raw = pendingRaw;
        flush();
    }

    /**
     * Changes the level by a delta, aligned to multiples of its size so keys give even values.
     * @param {real} delta  signed step size
     */
    function step(delta) {
        if (!available || delta === 0)
            return;
        const size = Math.abs(delta);
        // A level read from hardware can land just off a step (59.996% instead of 60%),
        // so nearby values snap to the closest step.
        const steps = level / size;
        const near = Math.abs(steps - Math.round(steps)) < 0.1;
        const base = delta > 0 ? (near ? Math.round(steps) : Math.floor(steps)) : (near ? Math.round(steps) : Math.ceil(steps));
        setLevel((base + (delta > 0 ? 1 : -1)) * size);
    }

    /** Writes the latest pending value. Slider drags outrun brightnessctl, so only one write runs at a time and the last value always wins. */
    function flush() {
        if (writer.running || pendingRaw < 0)
            return;
        writer.command = ["brightnessctl", "-q", "-d", device, "set", String(pendingRaw)];
        pendingRaw = -1;
        writer.running = true;
    }

    Process {
        command: ["brightnessctl", "-m", "-l", "-c", root.deviceClass]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const fields = line.split(",");
                    if (fields.length >= 5 && fields[0].includes(root.nameContains)) {
                        root.device = fields[0];
                        root.raw = parseInt(fields[2]);
                        root.maxRaw = parseInt(fields[4]);
                        break;
                    }
                }
            }
        }
    }

    Process {
        id: writer
        onExited: root.flush()
    }

    FileView {
        id: valueFile
        path: root.device !== "" ? `/sys/class/${root.deviceClass === "leds" ? "leds" : "backlight"}/${root.device}/brightness` : ""
        printErrors: false
        // inotify also sees changes from keys; udev does not report them for keyboards.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const value = parseInt(text());
            if (!isNaN(value) && !writer.running && root.pendingRaw < 0)
                root.raw = value;
        }
    }
}
