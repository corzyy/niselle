pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Systemaktualisierungen (Fedora, dnf5). Die Prüfung läuft ohne Rechte (`dnf5 repoquery --upgrades`), die Installation
// über `pkexec dnf5 upgrade`: Polkit fragt über den Agenten der Shell (modules/polkit) nach dem Passwort.
//
// state: "idle" | "checking" | "installing" | "done" (Installation fertig) | "failed" (Fehler in `error`)
// Ohne dnf5 ist `supported` false und die Leiste zeigt nichts.
Singleton {
    id: root

    // [{ name, version, arch, repo }], nach Name sortiert
    property var updates: []
    readonly property int count: updates.length
    readonly property bool available: count > 0
    property string state: "idle"
    readonly property bool checking: state === "checking"
    readonly property bool installing: state === "installing"
    property bool supported: true
    // Letzte Zeile der Installationsausgabe und die letzten Zeilen für Fehlermeldungen
    property string status: ""
    property string error: ""
    property date lastChecked: new Date(0)
    property var _log: []

    readonly property bool enabled: SettingsService.updatesAutoCheck && supported

    function check() {
        if (!supported || state === "checking" || state === "installing")
            return;
        state = "checking";
        error = "";
        checkProc.running = true;
    }

    function install() {
        if (!supported || state === "installing" || !available)
            return;
        state = "installing";
        status = "Waiting for authorization …";
        error = "";
        _log = [];
        installProc.running = true;
    }

    // Beendet eine fertige/fehlgeschlagene Anzeige und prüft neu
    function dismiss() {
        state = "idle";
        check();
    }

    Process {
        id: checkProc
        // Metadaten neu laden, sonst bleiben Meldungen bis zu 2 Tage alt. Schlüsselabfragen werden verneint (stdin zu).
        command: ["sh", "-c", "command -v dnf5 >/dev/null || exit 3; exec dnf5 repoquery --upgrades --latest-limit=1 --refresh --assumeno -q --queryformat '%{name}|%{evr}|%{arch}|%{repoid}\\n'"]
        environment: ({
                "LC_ALL": "C"
            })

        property var found: []

        onStarted: found = []
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split("|");
                if (p.length === 4 && p[0] !== "")
                    checkProc.found.push({
                        "name": p[0],
                        "version": p[1],
                        "arch": p[2],
                        "repo": p[3]
                    });
            }
        }
        onExited: code => {
            if (code === 3) {
                root.supported = false;
                root.state = "idle";
                return;
            }
            // Bei einem Fehler (offline, Paketquelle) die bisherige Liste behalten
            if (code === 0) {
                root.updates = found.sort((a, b) => a.name.localeCompare(b.name));
                root.lastChecked = new Date();
            }
            root.state = "idle";
        }
    }

    Process {
        id: installProc
        // -y: die Rückfrage übernimmt die Polkit-Anmeldung; --refresh, damit genau die geprüften Pakete kommen
        command: ["pkexec", "dnf5", "upgrade", "-y", "--refresh"]

        function note(line) {
            const t = line.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").trim();
            if (t === "")
                return;
            root.status = t;
            root._log = root._log.concat([t]).slice(-8);
        }

        stdout: SplitParser {
            onRead: line => installProc.note(line)
        }
        stderr: SplitParser {
            onRead: line => installProc.note(line)
        }
        onExited: code => {
            // pkexec: 126 = Anmeldung abgebrochen, 127 = nicht autorisiert
            if (code === 126 || code === 127) {
                root.state = "idle";
                root.status = "";
                return;
            }
            if (code === 0) {
                root.state = "done";
                root.updates = [];
                root.status = "";
                root.lastChecked = new Date();
            } else {
                root.state = "failed";
                root.error = root._log.length > 0 ? root._log.slice(-3).join("\n") : "dnf exited with code " + code;
            }
        }
    }

    // Erste Prüfung kurz nach dem Start, danach im eingestellten Abstand
    Timer {
        interval: 20000
        running: root.enabled
        onTriggered: root.check()
    }
    Timer {
        interval: SettingsService.updatesCheckHours * 3600 * 1000
        repeat: true
        running: root.enabled
        onTriggered: root.check()
    }
    // Wieder eingeschaltet: sofort prüfen
    onEnabledChanged: if (enabled)
        check()
}
