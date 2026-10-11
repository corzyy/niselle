pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Hintergrundbild je Monitor für die Arbeitsflächen-Vorschauen. Quelle: awww (`awww query`, zeigt, was tatsächlich
// auf dem Monitor liegt), sonst die Einstellung wallpaper(Dark) aus SettingsService. Fehlt beides, bleibt `sourceFor` leer.
// awww meldet keine Ereignisse; abgefragt wird deshalb nur beim Öffnen der Übersicht.
// Beim Start wird das gemerkte Hintergrundbild einmal wiederhergestellt: awww überlebt keinen Reboot, ohne einen
// Aufruf bliebe der Desktop nach dem Login leer.
Singleton {
    id: root

    // { Monitorname: Dateipfad }
    property var awwwPaths: ({})

    // Eingestelltes Hintergrundbild als Dateipfad (Dark-Variante im dunklen Stil), ohne file://-Präfix
    readonly property string configuredPath: {
        const path = Theme.dark && SettingsService.wallpaperDark !== "" ? SettingsService.wallpaperDark : SettingsService.wallpaper;
        return path.startsWith("file://") ? path.slice(7) : path;
    }

    // Eingestelltes Hintergrundbild als file://-URL
    readonly property string configuredUri: root.configuredPath === "" ? "" : "file://" + root.configuredPath

    // file://-URL des Hintergrunds, "" wenn unbekannt
    function sourceFor(screenName) {
        const p = root.awwwPaths[screenName];
        if (p)
            return "file://" + p;
        return root.configuredUri;
    }

    // Wie sourceFor, aber ohne Rückfall auf die Einstellung: "" solange awww nichts meldet.
    // Für das Vorladen, damit kein nicht ladbarer Ersatz (z. B. .jxl) angefasst wird.
    function awwwSourceFor(screenName) {
        const p = root.awwwPaths[screenName];
        return p ? "file://" + p : "";
    }

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    // Gemerktes Hintergrundbild beim Start setzen, solange awww noch kein Bild anzeigt (z. B. direkt nach dem Booten).
    // Nur einmal; wartet, bis die Einstellungen aus der Datei geladen sind. Startet awww-daemon bei Bedarf, da er
    // einen Reboot nicht überlebt.
    property bool _restoreTried: false

    readonly property string restoreScript:
        "command -v awww >/dev/null 2>&1 || exit 0\n" +
        "awww query 2>/dev/null | grep -q 'image:' && exit 0\n" +
        "if ! pgrep -x awww-daemon >/dev/null 2>&1; then\n" +
        "  setsid awww-daemon >/dev/null 2>&1 &\n" +
        "  i=0; while [ $i -lt 20 ]; do pgrep -x awww-daemon >/dev/null 2>&1 && break; sleep 0.1; i=$((i+1)); done\n" +
        "  sleep 0.2\n" +
        "fi\n" +
        "awww img \"$1\""

    function restore() {
        if (root._restoreTried || !SettingsService.loaded)
            return;
        const img = root.configuredPath;
        if (img === "")
            return;
        root._restoreTried = true;
        restoreProc.command = ["sh", "-c", root.restoreScript, "sh", img];
        restoreProc.running = true;
    }

    Process {
        id: restoreProc
        onExited: root.refresh()
    }

    // Per Drag & Drop abgelegte Bilder: in <XDG-Bilderordner>/wallpapers kopieren (außer sie liegen dort schon,
    // bei Namensgleichheit mit anderem Inhalt wird durchnummeriert), dann als Hintergrund setzen.
    function isImage(path) {
        return /\.(jpe?g|png|webp|bmp|gif|avif|jxl)$/i.test(path);
    }

    function importAndApply(urls) {
        const files = urls.map(u => decodeURIComponent(u.toString().replace(/^file:\/\//, ""))).filter(root.isImage);
        if (files.length === 0 || importProc.running)
            return;
        // Das zuletzt abgelegte Bild wird gesetzt, alle werden kopiert
        const script = 'pics=$(xdg-user-dir PICTURES 2>/dev/null); [ -n "$pics" ] || pics="$HOME/Pictures"; dir="$pics/wallpapers"; mkdir -p "$dir" || exit 1\n' +
            'for f in "$@"; do\n' +
            '  [ -f "$f" ] || continue\n' +
            '  case "$(realpath "$f")" in "$(realpath "$dir")"/*) out=$f; continue_=1;; *) continue_=0;; esac\n' +
            '  if [ "$continue_" = 0 ]; then\n' +
            '    base=$(basename "$f"); name=${base%.*}; ext=${base##*.}; out="$dir/$base"; n=1\n' +
            '    while [ -e "$out" ] && ! cmp -s "$f" "$out"; do out="$dir/$name-$n.$ext"; n=$((n+1)); done\n' +
            '    [ -e "$out" ] || cp -- "$f" "$out" || exit 1\n' +
            '  fi\n' +
            'done\n' +
            '[ -n "$out" ] && printf "%s" "$out"';
        importProc.command = ["sh", "-c", script, "sh"].concat(files);
        importProc.running = true;
    }

    Process {
        id: importProc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path === "")
                    return;
                SettingsService.set("wallpaper", path);
                SettingsService.set("wallpaperHistory", [path].concat(SettingsService.wallpaperHistory.filter(p => p !== path)).slice(0, 50));
                applyProc.command = ["sh", "-c", 'command -v awww >/dev/null 2>&1 && awww img --transition-type grow --transition-pos center --transition-duration 1.2 --transition-fps 60 "$1"', "sh", path];
                applyProc.running = true;
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            root.refresh();
            if (SettingsService.useMatugen && MatugenService.available)
                MatugenService.regenerate();
        }
    }

    Component.onCompleted: {
        root.refresh();
        root.restore();
    }

    Connections {
        target: SettingsService
        function onLoadedChanged() {
            root.restore();
        }
    }

    Connections {
        target: OverviewService
        function onShownChanged() {
            if (OverviewService.shown)
                root.refresh();
        }
    }

    // Zeilen: ": HDMI-A-1: 1920x1080, scale: 1, currently displaying: image: /pfad/bild.jpg"
    Process {
        id: query
        command: ["sh", "-c", "command -v awww >/dev/null 2>&1 && awww query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^:\s*([^:]+):.*image:\s*(.+)$/);
                    if (m)
                        out[m[1].trim()] = m[2].trim();
                }
                root.awwwPaths = out;
            }
        }
    }
}
