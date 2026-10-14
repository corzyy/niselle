pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false

    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false
    readonly property bool canLock: sessionId !== ""
    readonly property bool canLogout: sessionId !== ""

    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""

    readonly property bool canScreenshot: ScreenshotService.canScreenshot
    readonly property bool canOpenSettings: true
    property bool canOpenTerminal: false
    property string terminalBin: ""

    property bool dryRun: false

    signal triggered(string action)

    function lock() {
        _run("lock", ["loginctl", "lock-session"]);
    }
    function logout() {
        if (canLogout)
            _run("logout", ["loginctl", "terminate-session", root.sessionId]);
    }
    function suspend() {
        if (!canSuspend)
            return;
        if (SettingsService.lockBeforeSuspend) {
            LockService.lock();
            _run("suspend", ["sh", "-c", "sleep 0.6; exec systemctl suspend"]);
        } else {
            _run("suspend", ["systemctl", "suspend"]);
        }
    }
    function reboot() {
        if (canReboot)
            _run("reboot", ["systemctl", "reboot"]);
    }
    function powerOff() {
        if (canPowerOff)
            _run("poweroff", ["systemctl", "poweroff"]);
    }

    function screenshot() {
        ScreenshotService.show("screenshot");
    }
    readonly property var settingsPanels: ({
            "wifi": "network",
            "bluetooth": "bluetooth",
            "sound": "sound",
            "power": "power",
            "display": "displays",
            "background": "appearance"
        })
    function openSettings(panel) {
        SettingsWindowService.show(settingsPanels[panel] ?? panel ?? "");
    }
    function terminal() {
        if (canOpenTerminal)
            _run("terminal", ["sh", "-c", 'cd "$HOME" && exec "$0"', root.terminalBin]);
    }

    function _run(action, command) {
        console.log("SessionService:", action, root.dryRun ? "(dryRun)" : "", command.join(" "));
        root.triggered(action);
        if (!root.dryRun)
            Quickshell.execDetached(command);
    }

    function _allowed(answer) {
        return answer === "yes" || answer === "challenge";
    }

    Process {
        running: true
        command: ["sh", "-c", 'if command -v xdg-terminal-exec >/dev/null 2>&1; then echo "terminal xdg-terminal-exec"; elif [ -n "$TERMINAL" ] && command -v "$TERMINAL" >/dev/null 2>&1; then echo "terminal $TERMINAL"; else for t in gnome-terminal kgx kitty foot wezterm alacritty konsole xterm; do if command -v "$t" >/dev/null 2>&1; then echo "terminal $t"; break; fi; done; fi; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n");
                for (const line of found) {
                    if (line.startsWith("terminal ")) {
                        root.terminalBin = line.slice("terminal ".length).trim();
                        root.canOpenTerminal = root.terminalBin !== "";
                    }
                }
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'for m in CanSuspend CanReboot CanPowerOff; do printf "%s " "$m"; busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$m" 2>/dev/null || echo \'s "na"\'; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const answers = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\w+) s "(\w+)"/);
                    if (m)
                        answers[m[1]] = m[2];
                }
                root.available = Object.keys(answers).some(k => answers[k] !== "na");
                root.canSuspend = root._allowed(answers.CanSuspend);
                root.canReboot = root._allowed(answers.CanReboot);
                root.canPowerOff = root._allowed(answers.CanPowerOff);
            }
        }
    }

    IpcHandler {
        target: "session"

        function suspend(): void {
            root.suspend();
        }
    }
}
