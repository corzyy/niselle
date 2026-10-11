pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Alt+Tab-Umschalter. `niselle switcher next|prev|window` (Hyprland-Kürzel, siehe Settings › Keyboard) öffnet ihn:
//   next/prev   Apps, zuletzt benutzte zuerst; die aktuelle App steht vorn, die Auswahl beginnt bei der vorigen
//   window      Fenster der aktuellen App (Alt+`)
// Solange die Modifikatortaste gehalten wird, schalten weitere Aufrufe weiter; das Loslassen (Switcher.qml) aktiviert
// die Auswahl, Esc bricht ab. Die Fensterliste kommt frisch aus `hyprctl clients` (Reihenfolge: focusHistoryID).
Singleton {
    id: root

    property bool open: false
    // "apps" | "windows"
    property string mode: "apps"
    // [{ key, name, icon, windows: [{ address, title }] }]
    property var items: []
    property int index: 0

    readonly property var selected: root.items[root.index] ?? null

    // Alle Fenster (frisch gelesen), neuestes zuerst: { address, cls, title, workspace }
    property var _windows: []
    property var _queue: []
    property bool _loading: false

    function request(kind) {
        if (root.open) {
            root._step(kind);
            return;
        }
        root._queue = root._queue.concat([kind]);
        if (!root._loading) {
            root._loading = true;
            clients.running = true;
        }
    }
    function next() {
        root.request("next");
    }
    function prev() {
        root.request("prev");
    }
    function window() {
        root.request("window");
    }

    function close() {
        root.open = false;
        root.items = [];
        root._queue = [];
    }

    // Auswahl aktivieren und schließen
    function commit() {
        const item = root.selected;
        root.close();
        if (item && item.windows.length > 0)
            WorkspaceService.focusAddress(item.windows[0].address);
    }

    function _appItems() {
        const byClass = {};
        const out = [];
        for (const w of root._windows) {
            const key = w.cls.toLowerCase();
            let item = byClass[key];
            if (!item) {
                const entry = AppsService.entryForClass(w.cls);
                item = {
                    "key": key,
                    "cls": w.cls,
                    "name": entry ? entry.name : w.cls,
                    "icon": entry && entry.icon ? entry.icon : "application-x-executable",
                    "windows": []
                };
                byClass[key] = item;
                out.push(item);
            }
            item.windows.push(w);
        }
        return out;
    }

    function _windowItems(cls) {
        const entry = AppsService.entryForClass(cls);
        return root._windows.filter(w => w.cls.toLowerCase() === cls.toLowerCase()).map(w => ({
                    "key": w.address,
                    "cls": w.cls,
                    "name": w.title !== "" ? w.title : (entry ? entry.name : w.cls),
                    "icon": entry && entry.icon ? entry.icon : "application-x-executable",
                    "windows": [w]
                }));
    }

    function _wrap(i, n) {
        return ((i % n) + n) % n;
    }

    function _step(kind) {
        const n = root.items.length;
        if (n === 0)
            return;
        if (kind === "window") {
            if (root.mode !== "windows") {
                const cls = root.selected?.cls ?? "";
                const list = root._windowItems(cls);
                if (list.length === 0)
                    return;
                root.mode = "windows";
                root.items = list;
                root.index = list.length > 1 && list[0].windows[0].address === root._windows[0]?.address ? 1 : 0;
                return;
            }
            root.index = root._wrap(root.index + 1, n);
        } else {
            root.index = root._wrap(root.index + (kind === "prev" ? -1 : 1), n);
        }
    }

    function _begin() {
        const queue = root._queue;
        root._queue = [];
        if (queue.length === 0 || root._windows.length === 0)
            return;
        const first = queue[0];
        if (first === "window") {
            root.mode = "windows";
            root.items = root._windowItems(root._windows[0].cls);
        } else {
            root.mode = "apps";
            root.items = root._appItems();
        }
        // Nichts zum Umschalten: gar nicht erst öffnen
        if (root.items.length < 2)
            return;
        root.index = 0;
        root.open = true;
        for (const k of queue)
            root._step(k);
    }

    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._loading = false;
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    root._queue = [];
                    return;
                }
                root._windows = list.filter(c => c.mapped && !c.hidden && c.class && c.class !== "").sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => ({
                            "address": c.address,
                            "cls": c.class,
                            "title": c.title ?? "",
                            "workspace": c.workspace?.id ?? 0
                        }));
                root._begin();
            }
        }
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.next();
        }
        function prev(): void {
            root.prev();
        }
        function window(): void {
            root.window();
        }
        function close(): void {
            root.close();
        }
    }
}
