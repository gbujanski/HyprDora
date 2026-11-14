pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Online accounts, added only through the provider's own sign-in in the browser (Nextcloud Login Flow v2,
// OAuth for others later), so the shell never sees the account password. A provider issues a separate app
// password, kept in the keyring; settings.json keeps only the provider, server and login.
Singleton {
    id: root

    readonly property var providers: [
        {
            value: "nextcloud",
            label: "Nextcloud",
            fields: [
                {
                    key: "server",
                    label: I18n.t("accounts.server"),
                    placeholder: "https://cloud.example.com"
                }
            ]
        }
    ]

    // [{ provider, server, login }]
    readonly property var accounts: Settings.overrides.accounts ?? []

    // "" when idle, "starting" while asking the server, "waiting" while the browser sign-in is open.
    property string state: ""
    property string error: ""
    property var flow: null

    /**
     * Keyring key of an account.
     * @param {object} account  { provider, server, login }
     * @returns {string}
     */
    function id(account) {
        return `${account.provider}:${account.login}@${account.server}`;
    }

    /**
     * Starts adding an account: the provider's sign-in opens in the browser.
     * @param {string} provider  provider value
     * @param {object} values  field values by key
     */
    function add(provider, values) {
        if (state !== "")
            return;
        error = "";
        let server = (values.server ?? "").trim().replace(/\/+$/, "");
        if (server === "") {
            error = I18n.t("accounts.error.server");
            return;
        }
        if (!/^https?:\/\//.test(server))
            server = `https://${server}`;
        state = "starting";
        flow = {
            provider: provider,
            server: server
        };
        starter.command = ["curl", "-sS", "--fail", "--max-time", "15", "-X", "POST", "-A", "HyprDora", `${server}/index.php/login/v2`];
        starter.running = true;
    }

    /** Stops waiting for the browser sign-in. */
    function cancel() {
        pollTimer.stop();
        poller.running = false;
        state = "";
        flow = null;
    }

    /**
     * Signs an account out: the app password is revoked on the server and removed from the keyring.
     * @param {object} account  account from accounts
     */
    function remove(account) {
        remover.account = account;
        remover.running = true;
    }

    /**
     * Writes text to a process's input and closes it, so secrets never appear in its arguments.
     * @param {Process} process  started process
     * @param {string} text  input
     */
    function feed(process, text) {
        process.write(text);
        process.stdinEnabled = false;
    }

    /**
     * Quotes a value for a curl config file.
     * @param {string} text  value
     * @returns {string}
     */
    function curlQuoted(text) {
        return `"${String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    // Step 1: the server returns a sign-in address for the browser and a token to poll with.
    Process {
        id: starter

        stdout: StdioCollector {
            id: starterOutput
        }

        onExited: exitCode => {
            if (root.state !== "starting")
                return;
            let reply = null;
            try {
                reply = JSON.parse(starterOutput.text);
            } catch (e) {}
            if (exitCode !== 0 || !reply?.login || !reply?.poll) {
                root.error = I18n.t("accounts.error.unreachable");
                root.state = "";
                return;
            }
            root.flow = Object.assign({}, root.flow, {
                token: reply.poll.token,
                endpoint: reply.poll.endpoint,
                deadline: Date.now() + 20 * 60 * 1000
            });
            root.state = "waiting";
            Quickshell.execDetached(["xdg-open", reply.login]);
            pollTimer.start();
        }
    }

    // Step 2: until the sign-in is approved, the poll answers 404.
    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        onTriggered: {
            if (Date.now() > root.flow.deadline) {
                root.cancel();
                root.error = I18n.t("accounts.error.timeout");
                return;
            }
            if (!poller.running) {
                poller.stdinEnabled = true;
                poller.running = true;
            }
        }
    }

    Process {
        id: poller

        command: ["curl", "-sS", "--fail", "--max-time", "10", "-A", "HyprDora", "--config", "-"]

        // The token goes through the input, like the passwords.
        onStarted: root.feed(poller, `url = ${root.curlQuoted(root.flow.endpoint)}\ndata = ${root.curlQuoted(`token=${root.flow.token}`)}\n`)

        stdout: StdioCollector {
            id: pollOutput
        }

        onExited: exitCode => {
            if (exitCode !== 0 || root.state !== "waiting")
                return;
            let reply = null;
            try {
                reply = JSON.parse(pollOutput.text);
            } catch (e) {}
            if (!reply?.appPassword)
                return;
            pollTimer.stop();
            const account = {
                provider: root.flow.provider,
                server: (reply.server ?? root.flow.server).replace(/\/+$/, ""),
                login: reply.loginName
            };
            saver.account = account;
            saver.secret = reply.appPassword;
            saver.command = ["secret-tool", "store", `--label=HyprDora: ${account.provider} ${account.login}`, "application", "hyprdora", "account", root.id(account)];
            saver.stdinEnabled = true;
            saver.running = true;
        }
    }

    // Step 3: the app password goes to the keyring, the rest to settings.json.
    Process {
        id: saver

        property var account: null
        property string secret: ""

        onStarted: {
            root.feed(saver, secret);
            secret = "";
        }

        onExited: exitCode => {
            if (exitCode === 0)
                Settings.set("accounts", [...root.accounts.filter(a => root.id(a) !== root.id(account)), account]);
            else
                root.error = I18n.t("accounts.error.keyring");
            root.state = "";
            root.flow = null;
        }
    }

    // Signing out: the stored app password is read, revoked on the server, then removed locally.
    Process {
        id: remover

        property var account: null

        command: ["sh", "-c", `
            secret=$(secret-tool lookup application hyprdora account "$1") || secret=""
            if [ -n "$secret" ]; then
                printf 'url = "%s"\\nuser = "%s:%s"\\n' "$2/ocs/v2.php/core/apppassword" "$3" "$secret" |
                    curl -sS --fail --max-time 10 -X DELETE -H "OCS-APIRequest: true" -A HyprDora --config - >/dev/null
                revoked=$?
            else
                revoked=0
            fi
            secret-tool clear application hyprdora account "$1"
            exit $revoked`, "hyprdora-accounts", root.id(account ?? {}), account?.server ?? "", account?.login ?? ""]

        onExited: exitCode => {
            Settings.set("accounts", root.accounts.filter(a => root.id(a) !== root.id(account)));
            // Offline, the app password stays valid on the server until removed there.
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", `--app-name=${I18n.t("accounts.title")}`, I18n.t("accounts.revokeFailedTitle"), I18n.t("accounts.revokeFailedBody", {
                        server: account.server
                    })]);
        }
    }

    IpcHandler {
        target: "accounts"

        function describe(): string {
            return JSON.stringify({
                accounts: root.accounts,
                state: root.state,
                error: root.error
            });
        }
        function add(provider: string, server: string): void {
            root.add(provider, {
                server: server
            });
        }
    }
}
