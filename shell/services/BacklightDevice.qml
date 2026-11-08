import QtQuick
import Quickshell
import Quickshell.Io

// Jedno urządzenie podświetlenia obsługiwane przez brightnessctl.
// Poziom 0..1 jest liczony w skali odbieranej przez oko (moc = p^exponent,
// dla ekranu p^3 jak w CIE L*), a 0 oznacza minimumFraction mocy zamiast
// zgaszonego podświetlenia. Ta sama skala obsługuje suwak, OSD i klawisze (IPC).
Scope {
    id: root

    property string deviceClass: "backlight"
    property string nameContains: ""
    property real exponent: 1
    // Najniższa moc (ułamek maksimum) odpowiadająca poziomowi 0.
    property real minimumFraction: 0

    property string device: ""
    property int maxRaw: 0
    property int raw: 0
    property int pendingRaw: -1

    readonly property bool available: device !== "" && maxRaw > 0
    readonly property real floorPerceived: Math.pow(minimumFraction, 1 / exponent)
    // Wartość poniżej minimum (np. ustawiona spoza shella) pokazujemy jako 0.
    readonly property real level: available
        ? Math.max(0, Math.min(1, (Math.pow(raw / maxRaw, 1 / exponent) - floorPerceived) / (1 - floorPerceived)))
        : 0

    function rawFor(value) {
        const clamped = Math.max(0, Math.min(1, value));
        const perceived = floorPerceived + (1 - floorPerceived) * clamped;
        const minimumRaw = minimumFraction > 0 ? Math.max(1, Math.round(minimumFraction * maxRaw)) : 0;
        return Math.max(minimumRaw, Math.round(Math.pow(perceived, exponent) * maxRaw));
    }

    function setLevel(value) {
        if (!available) return;
        pendingRaw = rawFor(value);
        raw = pendingRaw;
        flush();
    }

    // Zmiana o delta z wyrównaniem do wielokrotności kroku, żeby klawisze
    // dawały równe wartości (35%, 40%…) niezależnie od punktu startu.
    function step(delta) {
        if (!available || delta === 0) return;
        const size = Math.abs(delta);
        // Poziom odczytany z wartości sprzętowej bywa o włos obok kroku (59,996%
        // zamiast 60%), więc bliskie wartości przyciągamy do najbliższego kroku.
        const steps = level / size;
        const near = Math.abs(steps - Math.round(steps)) < 0.1;
        const base = delta > 0
            ? (near ? Math.round(steps) : Math.floor(steps))
            : (near ? Math.round(steps) : Math.ceil(steps));
        setLevel((base + (delta > 0 ? 1 : -1)) * size);
    }

    // Przy przeciąganiu suwaka zmiany przychodzą szybciej, niż działa brightnessctl:
    // wykonujemy tylko jedną naraz i zawsze kończymy na ostatniej wartości.
    function flush() {
        if (writer.running || pendingRaw < 0) return;
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
        // inotify widzi też zmiany z klawiszy; udev nie zgłasza ich dla klawiatury.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const value = parseInt(text());
            if (!isNaN(value) && !writer.running && root.pendingRaw < 0) root.raw = value;
        }
    }
}
