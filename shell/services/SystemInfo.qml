pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The computer's name and what it is: hardware, system and versions, for the "about" settings. The name
// changes through systemd-hostnamed, which asks for the administrator password.
Singleton {
    id: root

    // Values read by reader, by key: pretty, static, transient, vendor, product, cpu, cores, memory, gpu,
    // diskSize, diskUsed, os, supportEnd, bits, arch, hyprdora, hyprland, kernel.
    property var info: ({})
    readonly property string name: info.pretty || info.static || info.transient || ""
    property bool saving: false
    property string error: ""

    /** Reads everything again. */
    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    /**
     * The network name made from a pretty name: letters without accents, digits and dashes, at most 63.
     * @param {string} pretty  such as Laptop Grzegorza
     * @returns {string} such as laptop-grzegorza
     */
    function networkName(pretty) {
        const plain = pretty.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[łŁ]/g, "l").replace(/ß/g, "ss").replace(/[æÆ]/g, "ae").replace(/[øØ]/g, "o");
        return plain.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 63).replace(/-+$/, "");
    }

    /**
     * Gives the computer a new name.
     * @param {string} pretty  name as shown, such as Laptop Grzegorza
     */
    function setName(pretty) {
        const text = pretty.trim();
        const network = networkName(text);
        if (saving || text === "" || network === "")
            return;
        saving = true;
        error = "";
        renamer.command = ["python3", "-I", Quickshell.shellPath("scripts/set-hostname.py"), text, network];
        renamer.running = true;
    }

    /**
     * Formats bytes as gigabytes, such as 8 GB or 237,4 GB.
     * @param {real} bytes  size
     * @returns {string}
     */
    function gigabytes(bytes) {
        const value = bytes / 1e9;
        return `${value.toLocaleString(I18n.locale, "f", value < 10 ? 1 : 0)} GB`;
    }

    // Rows shown in the settings and copied as text: [{ label, value }].
    readonly property var rows: {
        const i = info;
        const memory = Number(i.memory ?? 0) * 1024;
        const support = i.supportEnd ? new Date(`${i.supportEnd}T12:00:00`) : null;
        return [
            {
                key: "model",
                value: [i.vendor, i.product].filter(v => v && !/to be filled|default string|system product name/i.test(v)).join(" ")
            },
            {
                key: "cpu",
                value: i.cpu ? `${i.cpu} × ${i.cores}` : ""
            },
            {
                key: "memory",
                value: memory > 0 ? `${Math.round(memory / 1024 ** 3)} GB` : ""
            },
            {
                key: "graphics",
                value: i.gpu ?? ""
            },
            {
                key: "disk",
                value: i.diskSize ? I18n.t("about.diskValue", {
                    used: gigabytes(Number(i.diskUsed)),
                    size: gigabytes(Number(i.diskSize))
                }) : ""
            },
            {
                key: "os",
                value: i.os ?? ""
            },
            {
                key: "osType",
                value: i.bits ? I18n.t("about.bits", {
                    bits: i.bits,
                    arch: i.arch
                }) : ""
            },
            {
                key: "windowing",
                value: {
                    "wayland": "Wayland",
                    "x11": "X11"
                }[Quickshell.env("XDG_SESSION_TYPE")] ?? (Quickshell.env("WAYLAND_DISPLAY") ? "Wayland" : "")
            },
            {
                key: "supportEnd",
                value: support && !isNaN(support) ? support.toLocaleDateString(I18n.locale, "d MMMM yyyy") : ""
            },
            {
                key: "hyprdora",
                value: i.hyprdora ?? ""
            },
            {
                key: "hyprland",
                value: i.hyprland ?? ""
            },
            {
                key: "kernel",
                value: i.kernel ?? ""
            }
        ].filter(r => r.value !== "").map(r => ({
                    label: I18n.t(`about.${r.key}`),
                    value: r.value
                }));
    }

    /** Copies the name and the rows to the clipboard as text, one per line. */
    function copy() {
        const text = [`${I18n.t("about.name")}: ${name}`, ...rows.map(r => `${r.label}: ${r.value}`)].join("\n");
        copier.command = ["wl-copy", "--", text];
        copier.running = true;
    }

    Process {
        id: reader

        // One "key<TAB>value" per line. The graphics name prefers the marketing name in brackets, such as
        // Intel HD Graphics 6000 from "Intel Corporation Broadwell-U GT3 [HD Graphics 6000]".
        command: ["sh", "-c", `export LC_ALL=C
            p() { printf '%s\\t%s\\n' "$1" "$2"; }
            p pretty "$(hostnamectl --pretty 2>/dev/null)"
            p static "$(hostnamectl --static 2>/dev/null)"
            p transient "$(hostname 2>/dev/null)"
            p vendor "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
            p product "$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
            p cpu "$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1 | sed 's/(R)//g; s/(TM)//g; s/ CPU / /; s/  */ /g')"
            p cores "$(nproc)"
            p memory "$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
            lspci 2>/dev/null | sed -n 's/^[^ ]* \\(VGA compatible controller\\|3D controller\\|Display controller\\): //p' | while read -r line; do
                vendor=\${line%% *}
                case "$line" in *\\[*\\]*) model=\${line##*[}; model=\${model%%]*}; p gpu "$vendor $model" ;; *) p gpu "$line" ;; esac
            done | head -1
            df -B1 --output=size,used / | awk 'NR == 2 {printf "diskSize\\t%s\\ndiskUsed\\t%s\\n", $1, $2}'
            . /etc/os-release; p os "$PRETTY_NAME"; p supportEnd "\${SUPPORT_END:-}"
            p bits "$(getconf LONG_BIT)"
            p arch "$(uname -m)"
            p hyprdora "$(rpm -q --qf '%{version}' hyprdora 2>/dev/null)"
            p hyprland "$(hyprctl version -j 2>/dev/null | sed -n 's/.*"version": *"v\\{0,1\\}\\([^"]*\\)".*/\\1/p' | head -1)"
            p kernel "$(uname -r)"`]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0 && !(line.slice(0, tab) in values))
                        values[line.slice(0, tab)] = line.slice(tab + 1).trim();
                }
                // rpm prints a message when the package is missing, such as in a development copy.
                if (/not installed/.test(values.hyprdora ?? ""))
                    values.hyprdora = "";
                root.info = values;
            }
        }
    }

    Process {
        id: renamer

        stderr: StdioCollector {
            id: renamerErrors
        }

        onExited: exitCode => {
            root.saving = false;
            if (exitCode !== 0) {
                const reason = renamerErrors.text.trim();
                // Closing the password window is not an error worth showing.
                if (!/NotAuthorized|AccessDenied|Cancelled|dismissed/i.test(reason))
                    root.error = I18n.t("about.renameFailed");
            }
            root.refresh();
        }
    }

    Process {
        id: copier
    }

    IpcHandler {
        target: "about"

        function describe(): string {
            return JSON.stringify({
                name: root.name,
                info: root.info,
                rows: root.rows
            });
        }
        function networkName(pretty: string): string {
            return root.networkName(pretty);
        }
    }
}
