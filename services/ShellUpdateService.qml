pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aktualisiert die Shell (bin/niselle-update-shell): zieht den neuesten Commit aus dem
// Git-Remote und startet die Shell danach neu. Beginnt zurückhaltend und meldet dann
// eine Zusammenfassung; die eigentliche Ausgabe kommt als "<kind>|<text>"-Zeilen.
//
// state: "idle" | "running" | "done" | "failed"
Singleton {
    id: root

    property string state: "idle"
    readonly property bool running: state === "running"
    // Letzte Statuszeile des Skripts (z. B. "Already up to date")
    property string message: ""

    function start() {
        if (running)
            return;
        message = "";
        state = "running";
        proc.running = true;
    }

    Process {
        id: proc
        command: [Quickshell.shellPath("bin/niselle-update-shell")]

        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("|");
                if (i > 0)
                    root.message = line.slice(i + 1);
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "")
                    root.message = line.trim();
            }
        }
        onExited: code => {
            if (code === 0) {
                root.state = "done";
            } else {
                root.state = "failed";
                if (root.message === "")
                    root.message = "Update failed";
            }
        }
    }
}
