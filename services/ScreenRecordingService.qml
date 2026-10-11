pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bildschirmaufnahme über gpu-screen-recorder, wf-recorder oder wl-screenrec (in dieser Reihenfolge, was installiert ist). Ob eine Aufnahme läuft, kommt allein aus
// der Prozessliste (Abfrage alle 2 s): so erscheint auch eine Aufnahme, die außerhalb der Shell gestartet wurde, und
// sie überlebt einen Neustart der Shell. Beenden schickt SIGINT, damit der Rekorder die Datei sauber abschließt.
Singleton {
    id: root

    // Programme in Reihenfolge der Vorliebe: [Prozessname, Aufruf zum Starten mit Bereich $area und Datei $file]
    readonly property var backends: [
        {
            // GPU-Kodierung (NVENC/VAAPI), schont die CPU. Bereich "x,y BxH" wird zu "BxH+x+y"
            "bin": "gpu-screen-recorder",
            "proc": "gpu-screen-reco",
            "start": 'set -- $(echo "$area" | tr ",x" "  "); case $1 in -*) sx= ;; *) sx=+ ;; esac; case $2 in -*) sy= ;; *) sy=+ ;; esac; exec gpu-screen-recorder -w region -region "${3}x${4}${sx}${1}${sy}${2}" -f 60 -o "$file"'
        },
        {
            "bin": "wf-recorder",
            "proc": "wf-recorder",
            "start": 'exec wf-recorder -g "$area" -f "$file"'
        },
        {
            "bin": "wl-screenrec",
            "proc": "wl-screenrec",
            "start": 'exec wl-screenrec -g "$area" -f "$file"'
        }
    ]
    readonly property string procPattern: "wf-recorder|wl-screenrec|gpu-screen-reco"

    // Aufnahme starten ist möglich (Rekorder installiert; der Bereich kommt aus der Oberfläche ScreenshotService)
    property bool canRecord: false
    property string _backend: ""

    // Eine Aufnahme läuft gerade (auch von außerhalb)
    property bool recording: false
    // Beginn der Aufnahme (ms seit Epoche) und Dauer in Sekunden, jede Sekunde aktualisiert
    property double startedAt: 0
    property int elapsed: 0

    // "0:32" bzw. "1:02:03"
    readonly property string elapsedText: {
        const s = elapsed % 60, m = Math.floor(elapsed / 60) % 60, h = Math.floor(elapsed / 3600);
        const two = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + two(m) + ":" + two(s) : m + ":" + two(s);
    }

    // Aufnahmeoberfläche öffnen (Bereich, Bildschirm oder Fenster wählen)
    function start() {
        if (!canRecord || recording)
            return;
        ScreenshotService.show("record");
    }
    // Bereich $1 (Format "x,y BxH" wie bei slurp) aufnehmen und im XDG-Videos-Ordner speichern
    function startArea(area) {
        if (!canRecord || recording)
            return;
        const b = root.backends.find(x => x.bin === root._backend);
        const script = 'dir=$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos"); mkdir -p "$dir" || exit 1; area="$1"; file="$dir/$(date +"Screencast from %Y-%m-%d %H-%M-%S").mp4"; ' + b.start;
        console.log("ScreenRecordingService: start", b.bin, area);
        Quickshell.execDetached(["sh", "-c", script, "sh", area]);
        recheck.restart();
    }
    function stop() {
        if (!recording)
            return;
        console.log("ScreenRecordingService: stop");
        Quickshell.execDetached(["pkill", "-INT", "-x", root.procPattern]);
        recheck.restart();
    }
    function toggle() {
        if (recording)
            stop();
        else
            start();
    }

    Process {
        running: true
        command: ["sh", "-c", 'for b in gpu-screen-recorder wf-recorder wl-screenrec; do command -v "$b" >/dev/null && { echo "$b"; break; }; done; true']
        stdout: StdioCollector {
            onStreamFinished: {
                root._backend = text.trim();
                root.canRecord = root._backend !== "";
            }
        }
    }

    // Älteste laufende Aufnahme: Laufzeit in Sekunden oder leer
    Process {
        id: query
        command: ["sh", "-c", 'p=$(pgrep -xo "' + root.procPattern + '") && ps -o etimes= -p "$p"; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const secs = parseInt(text.trim());
                if (isNaN(secs)) {
                    root.recording = false;
                    root.elapsed = 0;
                    return;
                }
                root.startedAt = Date.now() - secs * 1000;
                root.elapsed = secs;
                root.recording = true;
            }
        }
    }

    Timer {
        id: poll
        // Im Leerlauf seltener nachsehen (jeder Durchlauf startet sh, pgrep und ps)
        interval: root.recording ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

    // Kurz nach Start/Stopp sofort nachsehen, statt auf den trägen Leerlauf-Takt zu warten
    Timer {
        id: recheck
        interval: 700
        onTriggered: {
            query.running = true;
            poll.restart();
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000))
    }
}
