pragma Singleton

import QtCore as Core
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screenshots and screen recording; modules/capture draws the selection overlay.
Singleton {
    id: root

    readonly property string renderNode: "/dev/dri/renderD128"
    // Tried in order. Fedora's own libavcodec has no libx264, but it can use libopenh264.
    readonly property var encoders: [["-c", "h264_vaapi", "-d", renderNode], ["-c", "libx264"], ["-c", "libopenh264"]]
    // An encoder that cannot start fails within this time.
    readonly property int encoderFailureWindow: 3000
    // Layers need a moment to disappear, or they would appear in the capture.
    readonly property int hideDelay: 200

    property bool overlayOpen: false
    property var overlayScreen: null
    property string mode: "area"
    property string kind: "screenshot"

    // Local to its screen: { screen, x, y, width, height }.
    property var area: null
    property var hoveredScreen: null
    property var hoveredWindow: null
    property var windows: []
    property string clientsJson: ""

    property bool recording: false
    property int elapsedSeconds: 0
    property real recordingStart: 0
    property string recordingFile: ""
    property string pendingGeometry: ""
    property string pendingKind: ""
    // wf-recorder options for sound, and the PipeWire modules loaded to mix two sources.
    property var audioArgs: []
    property var audioModules: []
    readonly property string mixSink: "hyprdora_capture_mix"
    // AAC rather than wf-recorder's default Opus, which many phones and chat apps do not play from MP4.
    readonly property var audioCodec: ["-C", "aac"]

    readonly property bool canCapture: {
        switch (mode) {
        case "area":
            return area !== null;
        case "window":
            return hoveredWindow !== null;
        default:
            return hoveredScreen !== null;
        }
    }
    readonly property string elapsedText: `${Math.floor(elapsedSeconds / 60)}:${String(elapsedSeconds % 60).padStart(2, "0")}`

    /** Opens the overlay, or stops a running recording. */
    function toggle() {
        if (recording)
            stopRecording();
        else if (overlayOpen)
            close();
        else
            open();
    }

    /** Opens the overlay on the focused screen. */
    function open() {
        if (recording)
            return;
        Panels.close("actioncenter");
        Panels.close("calendar");
        overlayScreen = Panels.focusedScreen();
        hoveredScreen = overlayScreen;
        hoveredWindow = null;
        if (!clientsQuery.running)
            clientsQuery.running = true;
        overlayOpen = true;
    }

    /** Closes the overlay without capturing. */
    function close() {
        overlayOpen = false;
    }

    /**
     * Stores the area selection, kept inside its screen.
     * @param {ShellScreen} screen  screen being drawn on
     * @param {real} x  left edge
     * @param {real} y  top edge
     * @param {real} width  width
     * @param {real} height  height
     */
    function setArea(screen, x, y, width, height) {
        const left = Math.round(Math.max(0, Math.min(x, x + width)));
        const top = Math.round(Math.max(0, Math.min(y, y + height)));
        const right = Math.round(Math.min(screen.width, Math.max(x, x + width)));
        const bottom = Math.round(Math.min(screen.height, Math.max(y, y + height)));
        if (right - left < 4 || bottom - top < 4)
            return;
        area = {
            screen: screen.name,
            x: left,
            y: top,
            width: right - left,
            height: bottom - top
        };
    }

    /**
     * Returns the highlighted rectangle on a screen.
     * @param {ShellScreen} screen  screen being drawn
     * @returns {object} { x, y, width, height } local to the screen, or null
     */
    function targetFor(screen) {
        switch (mode) {
        case "area":
            return area?.screen === screen.name ? area : null;
        case "window":
            {
                const w = hoveredWindow;
                if (!w || !contains(screen, w.x + w.width / 2, w.y + w.height / 2))
                    return null;
                return {
                    x: w.x - screen.x,
                    y: w.y - screen.y,
                    width: w.width,
                    height: w.height
                };
            }
        default:
            return hoveredScreen === screen ? {
                x: 0,
                y: 0,
                width: screen.width,
                height: screen.height
            } : null;
        }
    }

    /**
     * Tells whether a global point lies on a screen.
     * @param {ShellScreen} screen  screen to test
     * @param {real} x  global position
     * @param {real} y  global position
     * @returns {bool}
     */
    function contains(screen, x, y) {
        return x >= screen.x && x < screen.x + screen.width && y >= screen.y && y < screen.y + screen.height;
    }

    /**
     * Updates the window under the pointer. The last one stays selected when the pointer leaves it.
     * @param {ShellScreen} screen  screen under the pointer
     * @param {real} x  position local to the screen
     * @param {real} y  position local to the screen
     */
    function hoverAt(screen, x, y) {
        hoveredScreen = screen;
        const gx = screen.x + x;
        const gy = screen.y + y;
        hoveredWindow = windows.find(w => gx >= w.x && gx < w.x + w.width && gy >= w.y && gy < w.y + w.height) ?? hoveredWindow;
    }

    /**
     * Keeps windows that are on an active workspace, topmost first.
     * @param {string} clients  output of `hyprctl -j clients`
     * @param {string} monitors  output of `hyprctl -j monitors`
     * @returns {list}
     */
    function visibleWindows(clients, monitors) {
        try {
            const active = [];
            for (const monitor of JSON.parse(monitors))
                active.push(monitor.activeWorkspace.id, monitor.specialWorkspace.id);
            return JSON.parse(clients).filter(c => c.mapped && !c.hidden && active.includes(c.workspace.id)).sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => ({
                        x: c.at[0],
                        y: c.at[1],
                        width: c.size[0],
                        height: c.size[1]
                    }));
        } catch (e) {
            console.warn("capture: unreadable hyprctl response");
            return [];
        }
    }

    /**
     * Returns the selection as a global grim and wf-recorder geometry.
     * @returns {string} empty when nothing is selected
     */
    function geometry() {
        const screen = mode === "area" ? Quickshell.screens.find(s => s.name === area?.screen) : hoveredScreen;
        const local = screen ? targetFor(screen) : null;
        if (!local)
            return "";
        // Video encoders reject odd dimensions.
        const width = kind === "record" ? local.width - local.width % 2 : local.width;
        const height = kind === "record" ? local.height - local.height % 2 : local.height;
        return `${screen.x + local.x},${screen.y + local.y} ${width}x${height}`;
    }

    /** Hides the overlay and captures the selection. */
    function capture() {
        if (!canCapture)
            return;
        pendingGeometry = geometry();
        pendingKind = kind;
        if (pendingGeometry === "")
            return;
        overlayOpen = false;
        hideTimer.restart();
    }

    /**
     * Returns a path inside a standard directory.
     * @param {int} location  StandardPaths location
     * @param {string} folder  subdirectory
     * @returns {string}
     */
    function directory(location, folder) {
        return `${decodeURIComponent(String(Core.StandardPaths.writableLocation(location)).replace("file://", ""))}/${folder}`;
    }

    /**
     * Returns a file name based on the current time.
     * @param {string} extension  file extension
     * @returns {string}
     */
    function timestamped(extension) {
        return `${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.${extension}`;
    }

    /** Takes the pending screenshot. */
    function startScreenshot() {
        const folder = directory(Core.StandardPaths.PicturesLocation, "Screenshots");
        shooter.file = `${folder}/${timestamped("png")}`;
        shooter.command = ["grim", "-g", pendingGeometry, shooter.file];
        folderMaker.after = () => shooter.running = true;
        folderMaker.command = ["mkdir", "-p", folder];
        folderMaker.running = true;
    }

    /**
     * Starts wf-recorder on the pending geometry.
     * @param {int} encoder  index into encoders
     */
    function launchRecorder(encoder) {
        recorder.encoder = encoder;
        recorder.stopping = false;
        recorder.command = ["wf-recorder", "-y", "-g", pendingGeometry, "-f", recordingFile, ...encoders[encoder], ...audioArgs];
        recorder.running = true;
        recordingStart = Date.now();
        elapsedSeconds = 0;
        startCheck.restart();
    }

    /** Starts the pending recording. */
    function startRecording() {
        const folder = directory(Core.StandardPaths.MoviesLocation, "Recordings");
        recordingFile = `${folder}/${timestamped("mp4")}`;
        folderMaker.after = () => prepareAudio(() => launchRecorder(0));
        folderMaker.command = ["mkdir", "-p", folder];
        folderMaker.running = true;
    }

    /**
     * Picks the sound source for the recording. wf-recorder takes one source, so recording both the
     * system sound and the microphone first mixes them into a temporary sink.
     * @param {function} done  called when the source is ready
     */
    function prepareAudio(done) {
        const output = Audio.sink?.name ?? "";
        const input = Audio.source?.name ?? "";
        const wantOutput = Settings.captureSystemAudio && output !== "";
        const wantInput = Settings.captureMicrophone && input !== "";
        audioModules = [];
        if (!wantOutput && !wantInput) {
            audioArgs = [];
            done();
            return;
        }
        if (!(wantOutput && wantInput)) {
            audioArgs = [`--audio=${wantOutput ? `${output}.monitor` : input}`, ...audioCodec];
            done();
            return;
        }
        audioArgs = [`--audio=${mixSink}.monitor`, ...audioCodec];
        audioSetup.after = done;
        audioSetup.steps = [["pactl", "load-module", "module-null-sink", `sink_name=${mixSink}`, `sink_properties=device.description=${mixSink}`], ["pactl", "load-module", "module-loopback", `source=${output}.monitor`, `sink=${mixSink}`, "latency_msec=20"], ["pactl", "load-module", "module-loopback", `source=${input}`, `sink=${mixSink}`, "latency_msec=20"],
            // A new sink may become the default output, which would silence the speakers.
            ["pactl", "set-default-sink", output]];
        audioSetup.next();
    }

    /** Unloads the modules that mixed the sound. */
    function releaseAudio() {
        for (const id of [...audioModules].reverse())
            Quickshell.execDetached(["pactl", "unload-module", id]);
        audioModules = [];
    }

    /** Stops the recording with SIGINT, so wf-recorder finalizes the file. */
    function stopRecording() {
        if (!recording)
            return;
        recorder.stopping = true;
        recorder.signal(2);
    }

    /**
     * Copies a screenshot to the clipboard.
     * @param {string} file  image path
     */
    function copyToClipboard(file) {
        // Process cannot send binary data to stdin.
        Quickshell.execDetached(["sh", "-c", 'exec wl-copy --type image/png < "$1"', "hyprdora-copy", file]);
    }

    /**
     * Sends a notification with one optional action.
     * @param {string} summary  title
     * @param {string} body  text
     * @param {string} image  image path, optional
     * @param {string} actionLabel  button text, optional
     * @param {list} actionCommand  command run when the button is used, optional
     */
    function notify(summary, body, image, actionLabel, actionCommand) {
        // A screenshot's or recording's notice belongs to this session; the history does not keep it later.
        const command = ["notify-send", `--app-name=${I18n.t("capture.appName")}`, `--hint=boolean:${Notifications.sessionOnlyHint}:true`];
        if (image)
            command.push(`--hint=string:image-path:${image}`);
        if (actionLabel)
            command.push(`--action=run=${actionLabel}`);
        command.push(summary, body);
        notifier.createObject(root, {
            command: command,
            actionCommand: actionCommand ?? [],
            running: true
        });
    }

    Component {
        id: notifier

        Process {
            id: notification

            property var actionCommand: []

            stdout: SplitParser {
                onRead: line => {
                    if (line === "run" && notification.actionCommand.length > 0)
                        Quickshell.execDetached(notification.actionCommand);
                }
            }

            onExited: destroy()
        }
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: {
            if (root.pendingKind === "record")
                root.startRecording();
            else
                root.startScreenshot();
        }
    }

    // A program that cannot be started never reports started or exited.
    Timer {
        id: startCheck
        interval: 1000
        onTriggered: {
            if (!recorder.running)
                root.notify(I18n.t("capture.failed"), I18n.t("capture.failedBody"));
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSeconds = Math.round((Date.now() - root.recordingStart) / 1000)
    }

    Process {
        id: folderMaker

        property var after: null

        onExited: after()
    }

    Process {
        id: clientsQuery

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.clientsJson = text;
                monitorsQuery.running = true;
            }
        }
    }

    Process {
        id: monitorsQuery

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: root.windows = root.visibleWindows(root.clientsJson, text)
        }
    }

    Process {
        id: shooter

        property string file: ""

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.notify(I18n.t("capture.failed"), I18n.t("capture.failedBody"));
                return;
            }
            root.copyToClipboard(file);
            root.notify(I18n.t("capture.screenshotSaved"), I18n.t("capture.screenshotBody"), file, I18n.t("capture.edit"), ["swappy", "-f", file]);
        }
    }

    // Runs pactl commands one after another and remembers the module ids they print.
    Process {
        id: audioSetup

        property var steps: []
        property var after: null

        /** Runs the next command, or finishes when none are left. */
        function next() {
            if (steps.length === 0) {
                after();
                return;
            }
            command = steps[0];
            steps = steps.slice(1);
            running = true;
        }

        stdout: StdioCollector {
            id: setupOutput
        }

        onExited: exitCode => {
            const id = setupOutput.text.trim();
            if (/^\d+$/.test(id))
                root.audioModules = [...root.audioModules, id];
            if (exitCode !== 0 && command[1] === "load-module") {
                // Without the mix, the microphone alone is better than no sound at all.
                console.warn("capture: audio mix failed:", command.join(" "));
                root.releaseAudio();
                root.audioArgs = [`--audio=${Audio.source?.name ?? ""}`, ...root.audioCodec];
                steps = [];
            }
            next();
        }
    }

    Process {
        id: recorder

        property int encoder: 0
        property bool stopping: false

        stderr: StdioCollector {
            id: recorderErrors
        }

        onStarted: root.recording = true

        onExited: exitCode => {
            const failedEarly = !stopping && Date.now() - root.recordingStart < root.encoderFailureWindow;
            if (failedEarly && encoder + 1 < root.encoders.length) {
                console.info("capture: encoder unavailable:", root.encoders[encoder][1]);
                root.launchRecorder(encoder + 1);
                return;
            }
            root.recording = false;
            root.releaseAudio();
            if (stopping || exitCode === 0) {
                root.notify(I18n.t("capture.recordingSaved"), I18n.t("capture.recordingBody"), "", I18n.t("capture.open"), ["xdg-open", root.recordingFile]);
            } else {
                console.warn("capture: recording failed:", recorderErrors.text.trim());
                root.notify(I18n.t("capture.failed"), I18n.t("capture.failedBody"));
            }
        }
    }

    IpcHandler {
        target: "capture"

        function toggle(): void {
            root.toggle();
        }
        function describe(): string {
            return JSON.stringify({
                open: root.overlayOpen,
                mode: root.mode,
                kind: root.kind,
                area: root.area,
                windows: root.windows.length,
                canCapture: root.canCapture,
                geometry: root.geometry(),
                recording: root.recording,
                elapsed: root.elapsedSeconds,
                audioArgs: root.audioArgs,
                audioModules: root.audioModules
            });
        }
        function setMode(value: string): void {
            root.mode = value;
        }
        function setKind(value: string): void {
            root.kind = value;
        }
        function setArea(x: int, y: int, width: int, height: int): void {
            if (root.overlayScreen)
                root.setArea(root.overlayScreen, x, y, width, height);
        }
        function capture(): void {
            root.capture();
        }
        function stop(): void {
            root.stopRecording();
        }
    }
}
