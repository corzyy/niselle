pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var backends: [
        {
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

    property bool canRecord: false
    property string _backend: ""

    property bool recording: false
    property double startedAt: 0
    property int elapsed: 0

    readonly property string elapsedText: {
        const s = elapsed % 60, m = Math.floor(elapsed / 60) % 60, h = Math.floor(elapsed / 3600);
        const two = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + two(m) + ":" + two(s) : m + ":" + two(s);
    }

    function start() {
        if (!canRecord || recording)
            return;
        ScreenshotService.show("record");
    }
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
        interval: root.recording ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

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
