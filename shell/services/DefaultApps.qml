pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Default applications by kind, such as the browser or the image viewer. A choice is written for every
// file type of its kind to ~/.config/mimeapps.list, the same file other desktops and file managers use.
// The terminal has no file type, so it is kept in xdg-terminals.list for xdg-terminal-exec instead.
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
            types: ["text/plain"]
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

    // { kind: { current: "id.desktop" | "", choices: ["id.desktop", …] } }
    property var apps: ({})

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
        writer.command = kind === "terminal" ? ["sh", "-c", 'printf "%s\\n" "$1" > "${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"', "hyprdora-default-terminal", desktopId] : ["sh", "-c", 'app=$1; shift; for type; do gio mime "$type" "$app" >/dev/null || exit 1; done', "hyprdora-default-app", desktopId, ...kinds.find(k => k.id === kind).types];
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
