pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property bool canScreenshot: false
    readonly property bool canRecord: ScreenRecordingService.canRecord

    property bool open: false
    property string kind: "screenshot"
    property string mode: "selection"
    property bool showPointer: false
    property string panelScreen: ""
    property string activeScreen: ""
    property rect selection: Qt.rect(0, 0, 0, 0)
    property string windowAddress: ""
    property rect windowTarget: Qt.rect(0, 0, 0, 0)
    property var windows: []

    readonly property int hideDelay: 450

    function warnNoRecorder() {
        Quickshell.execDetached(["notify-send", "-a", "Screenshot", "Bildschirmaufnahme nicht verfügbar", "wf-recorder oder wl-screenrec ist nicht installiert (Fedora: sudo dnf install wf-recorder)."]);
    }

    function screenByName(name) {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    function show(kind) {
        if (root.open)
            return;
        const k = kind === "record" ? "record" : "screenshot";
        if (k === "record" ? !root.canRecord : !root.canScreenshot)
            return;
        root.kind = k;
        root.windowAddress = "";
        root.windowTarget = Qt.rect(0, 0, 0, 0);
        const mon = Hyprland.focusedMonitor;
        const fallback = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        const scr = (mon ? root.screenByName(mon.name) : null) ?? fallback;
        if (!scr)
            return;
        root.panelScreen = scr.name;
        root.activeScreen = scr.name;
        root.resetSelection(scr);
        root.refreshWindows();
        root.open = true;
    }
    function close() {
        root.open = false;
    }
    function toggle(kind) {
        if (root.open)
            root.close();
        else
            root.show(kind);
    }

    function selectWindow(w) {
        root.windowAddress = w.address;
        root.windowTarget = Qt.rect(w.x, w.y, w.w, w.h);
    }

    function resetSelection(scr) {
        const w = Math.round(scr.width / 2), h = Math.round(scr.height / 2);
        root.selection = Qt.rect(scr.x + Math.round((scr.width - w) / 2), scr.y + Math.round((scr.height - h) / 2), w, h);
    }

    function currentTarget() {
        if (root.mode === "selection")
            return root.selection;
        if (root.mode === "screen") {
            const s = root.screenByName(root.activeScreen);
            return s ? Qt.rect(s.x, s.y, s.width, s.height) : Qt.rect(0, 0, 0, 0);
        }
        return root.windowTarget;
    }

    function captureCurrent() {
        root.capture(root.currentTarget());
    }

    function capture(r) {
        if (!root.open || r.width < 1 || r.height < 1)
            return;
        const geom = Math.round(r.x) + "," + Math.round(r.y) + " " + Math.round(r.width) + "x" + Math.round(r.height);
        root.close();
        root._pendingGeom = geom;
        root._pendingKind = root.kind;
        root._pendingPointer = root.showPointer;
        delay.restart();
    }

    property string _pendingGeom: ""
    property string _pendingKind: "screenshot"
    property bool _pendingPointer: false

    Timer {
        id: delay
        interval: root.hideDelay
        onTriggered: {
            if (root._pendingKind === "record") {
                ScreenRecordingService.startArea(root._pendingGeom);
                return;
            }
            const script = 'dir=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures"); mkdir -p "$dir" || exit 1; ' + 'file="$dir/$(date +"Screenshot from %Y-%m-%d %H-%M-%S").png"; ' + 'grim $2 -g "$1" "$file" || { notify-send -a Screenshot "Bildschirmfoto fehlgeschlagen"; exit 1; }; ' + 'command -v wl-copy >/dev/null && wl-copy --type image/png < "$file"; ' + 'notify-send -a Screenshot -i "$file" "Bildschirmfoto aufgenommen" "$file"';
            console.log("ScreenshotService: grim", root._pendingGeom);
            Quickshell.execDetached(["sh", "-c", script, "sh", root._pendingGeom, root._pendingPointer ? "-c" : ""]);
        }
    }

    function refreshWindows() {
        windowsProc.running = true;
    }
    Process {
        id: windowsProc
        command: ["sh", "-c", 'hyprctl -j monitors; echo "@@SPLIT@@"; hyprctl -j clients']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("@@SPLIT@@");
                    const monitors = JSON.parse(parts[0]);
                    const clients = JSON.parse(parts[1]);
                    const visibleWs = monitors.map(m => m.activeWorkspace.id);
                    const list = clients.filter(c => c.mapped && !c.hidden && visibleWs.indexOf(c.workspace.id) >= 0 && c.size[0] > 0 && c.size[1] > 0);
                    list.sort((a, b) => (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID));
                    root.windows = list.map(c => ({
                                "address": c.address.replace(/^0x/, ""),
                                "x": c.at[0],
                                "y": c.at[1],
                                "w": c.size[0],
                                "h": c.size[1],
                                "title": c.title
                            }));
                } catch (e) {
                    console.warn("ScreenshotService: Fensterliste nicht lesbar:", e);
                    root.windows = [];
                }
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v grim >/dev/null && echo yes; true"]
        stdout: StdioCollector {
            onStreamFinished: root.canScreenshot = text.trim() === "yes"
        }
    }

    IpcHandler {
        target: "screenshot"

        function open(kind: string): void {
            root.show(kind);
        }
        function toggle(kind: string): void {
            root.toggle(kind);
        }
        function close(): void {
            root.close();
        }
        function mode(name: string): void {
            if (["selection", "screen", "window"].indexOf(name) >= 0)
                root.mode = name;
        }
        function capture(): void {
            root.captureCurrent();
        }
    }
}
