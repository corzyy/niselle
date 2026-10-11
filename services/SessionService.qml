pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sitzungsaktionen: Sperren, Abmelden, Standby, Neustart, Ausschalten (logind / systemd).
// `can*` stammt aus logind (CanSuspend usw.), einmal beim Start gelesen. Mit dryRun wird nur das Signal
// `triggered` gesendet und der Befehl protokolliert – für Tests.
Singleton {
    id: root

    // logind ist erreichbar
    property bool available: false

    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false
    // Sperren braucht einen Sperrbildschirm, der auf loginctl lock-session hört (hypridle/hyprlock o. ä.)
    readonly property bool canLock: sessionId !== ""
    readonly property bool canLogout: sessionId !== ""

    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""

    // grim (Bildschirmfoto-Oberfläche) und ein Terminal sind installiert. Die Einstellungen sind Teil der Shell.
    readonly property bool canScreenshot: ScreenshotService.canScreenshot
    readonly property bool canOpenSettings: true
    property bool canOpenTerminal: false
    // Gefundenes Terminal-Programm (xdg-terminal-exec, $TERMINAL oder eine bekannte Anwendung)
    property string terminalBin: ""

    // Nur protokollieren, nichts ausführen
    property bool dryRun: false

    // Aktion ("lock", "logout", "suspend", "reboot", "poweroff") wurde ausgelöst
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
        // Erst sperren (falls eingestellt), kurz warten, damit der Sperrbildschirm steht, bevor der Rechner schläft
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

    // Bildschirmfoto-Oberfläche öffnen (siehe ScreenshotService)
    function screenshot() {
        ScreenshotService.show("screenshot");
    }
    // Einstellungen-Fenster der Shell öffnen. panel: Name aus Schnellmenü/Desktopmenü (z. B. "wifi", "background"),
    // leer = zuletzt geöffneter Bereich. Wird auf die Bereichs-IDs in modules/settings abgebildet.
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
    // Terminal im Heimatverzeichnis öffnen („Im Terminal öffnen“)
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

    // "yes" und "challenge" (Rückfrage per polkit) zählen als erlaubt
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
