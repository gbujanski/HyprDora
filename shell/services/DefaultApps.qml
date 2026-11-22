pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Default applications by kind, such as the browser or the image viewer. A choice is written for the file
// types of its kind to ~/.config/mimeapps.list, the same file other desktops and file managers use; a type
// given an application of its own there, as with "Open With" in the file manager, keeps it. The terminal has
// no file type, so it is kept in xdg-terminals.list for xdg-terminal-exec instead.
Singleton {
    id: root

    // The first type of each kind decides which applications are offered and which one is current.
    readonly property var kinds: [
        {
            id: "browser",
            types: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml"]
        },
        {
            id: "mail",
            types: ["x-scheme-handler/mailto"]
        },
        {
            id: "files",
            types: ["inode/directory"]
        },
        {
            id: "terminal",
            types: []
        },
        {
            id: "editor",
            types: root.editorTypes
        },
        {
            id: "images",
            types: ["image/jpeg", "image/png", "image/gif", "image/webp", "image/svg+xml", "image/bmp", "image/tiff", "image/avif", "image/heif"]
        },
        {
            id: "video",
            types: ["video/mp4", "video/webm", "video/x-matroska", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg"]
        },
        {
            id: "music",
            types: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/x-opus+ogg", "audio/x-wav", "audio/mp4", "audio/aac"]
        },
        {
            id: "pdf",
            types: ["application/pdf"]
        }
    ]

    // Every text type, from the list the package writes from the MIME database for the system's editor.
    readonly property var editorTypes: ["text/plain", ...Object.keys(defaultsIn(editorTypesFile.text())).filter(t => t !== "text/plain")]

    // { kind: { current: "id.desktop" | "", choices: ["id.desktop", …] } }
    property var apps: ({})

    /**
     * Reads the default applications from a mimeapps.list.
     * @param {string} text  the file's contents
     * @returns {object} the first application of each type, by type
     */
    function defaultsIn(text) {
        const defaults = {};
        let inside = false;
        for (const line of (text ?? "").split("\n")) {
            if (line.startsWith("["))
                inside = line.trim() === "[Default Applications]";
            else if (inside && line.includes("=") && !line.startsWith("#")) {
                const [type, value] = [line.slice(0, line.indexOf("=")).trim(), line.slice(line.indexOf("=") + 1)];
                const app = value.split(";")[0].trim();
                if (app !== "")
                    defaults[type] = app;
            }
        }
        return defaults;
    }

    // Desktop entries load in the background, so names are looked up again as they arrive.
    readonly property int entryCount: DesktopEntries.applications.values.length

    /**
     * Returns the readable name of an application.
     * @param {string} desktopId  such as org.gnome.Loupe.desktop
     * @returns {string}
     */
    function name(desktopId) {
        void entryCount;
        const id = desktopId.replace(/\.desktop$/, "");
        return DesktopEntries.byId(id)?.name ?? id;
    }

    /** Reads the current applications and the choices again. */
    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    /**
     * Makes an application the default for a kind.
     * @param {string} kind  kind id
     * @param {string} desktopId  application
     */
    function set(kind, desktopId) {
        if (writer.running)
            return;
        if (kind === "terminal") {
            writer.command = ["sh", "-c", 'printf "%s\\n" "$1" > "${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"', "hyprdora-default-terminal", desktopId];
        } else {
            // The kind's own type always follows; another keeps an application chosen for it alone.
            const previous = apps[kind]?.current ?? "";
            userFile.reload();
            const own = defaultsIn(userFile.text());
            const types = kinds.find(k => k.id === kind).types.filter((type, i) => i === 0 || !own[type] || own[type] === previous);
            writer.command = ["sh", "-c", 'app=$1; shift; for type; do gio mime "$type" "$app" >/dev/null || exit 1; done', "hyprdora-default-app", desktopId, ...types];
        }
        writer.running = true;
    }

    // Prints, for each kind, its id, the current application or "-", and the choices, one per line, ending
    // with a blank line. The choices come from the desktop files themselves rather than gio, because Flatpak
    // does not always keep the cache gio reads; applications hidden from menus are left out. The terminals
    // are every application in the TerminalEmulator category.
    Process {
        id: reader

        command: ["sh", "-c", `
            export LC_ALL=C
            dirs="\${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            files=$(IFS=:; for dir in $dirs; do ls "$dir"/applications/*.desktop 2>/dev/null; done)
            visible=$(printf "%s\\n" "$files" | xargs -r -d "\\n" grep -L -e '^NoDisplay=true' -e '^Hidden=true' 2>/dev/null)
            while [ $# -gt 0 ]; do
                kind=$1 type=$2; shift 2
                echo "$kind"
                if [ "$kind" = terminal ]; then
                    current=$(xdg-terminal-exec --print-id 2>/dev/null | cut -d: -f1)
                    pattern='^Categories=.*TerminalEmulator'
                else
                    current=$(gio mime "$type" | sed -n 's/^Default application for .*: //p')
                    pattern="^MimeType=\\(.*;\\)\\?$type;"
                fi
                echo "\${current:--}"
                printf "%s\\n" "$visible" | xargs -r -d "\\n" grep -l -e "$pattern" 2>/dev/null | xargs -r -n1 basename | sort -u
                echo
            done`, "hyprdora-default-apps", ...[].concat(...root.kinds.map(k => [k.id, k.types[0] ?? ""]))]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const apps = {};
                for (const block of text.split("\n\n")) {
                    const lines = block.split("\n");
                    const kind = lines.shift();
                    if (!kind)
                        continue;
                    const current = lines.shift() ?? "-";
                    apps[kind] = {
                        current: current === "-" ? "" : current,
                        choices: [...new Set(lines.filter(Boolean))]
                    };
                }
                root.apps = apps;
            }
        }
    }

    Process {
        id: writer
        onExited: root.refresh()
    }

    FileView {
        id: editorTypesFile
        path: "/etc/xdg/hyprland-mimeapps.list"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: userFile
        path: `${Settings.configDir}/mimeapps.list`
        blockLoading: true
        printErrors: false
    }

    IpcHandler {
        target: "defaultapps"

        function describe(): string {
            return JSON.stringify(root.apps);
        }
        function set(kind: string, desktopId: string): void {
            root.set(kind, desktopId);
        }
    }
}
