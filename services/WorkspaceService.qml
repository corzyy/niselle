pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Arbeitsflächen und Fenster über Hyprland-IPC. Dynamische Arbeitsflächen wie in GNOME:
// je Monitor die belegten, aktiven oder persistenten Flächen plus immer eine leere am Ende.
// Dispatch läuft im Lua-Format (hl.dsp.*), wenn Hyprland eine Lua-Konfiguration nutzt, sonst im klassischen.
Singleton {
    id: root

    // Hyprland-IPC ist verbunden und kennt mindestens einen Monitor
    readonly property bool available: Hyprland.monitors.values.length > 0
    // Hyprland läuft mit Lua-Konfiguration (anderes Dispatch-Format)
    readonly property bool usingLua: Hyprland.usingLua

    readonly property var monitors: Hyprland.monitors.values
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var windows: Hyprland.toplevels.values
    readonly property var activeWindow: Hyprland.activeToplevel

    // Ereignis von Hyprland, z. B. ("openwindow", "...") – für Fälle, die die Eigenschaften nicht abdecken
    signal event(string name, string data)

    // Zählt Arbeitsflächen-/Monitorwechsel hoch. Bindungen, die von der aktiven Fläche abhängen
    // (Übersicht, Leiste), hängen hiervon ab, damit sie zuverlässig neu auswerten.
    property int revision: 0

    // Fenstergeometrie (lastIpcObject) veraltet bei Verschieben/Größenänderung; Hyprland meldet das nur als Ereignis.
    // Die Übersicht hängt hieran, damit das Layout nach jeder Änderung neu berechnet wird.
    property int geometryRevision: 0
    // Adressen von Fenstern, die gerade auf eine andere Fläche verschoben werden: sie verschwinden sofort aus dem
    // Layout der alten Fläche, statt bis zum IPC-Ereignis stehenzubleiben ({ address: true }).
    property var departing: ({})
    property int departingRevision: 0

    function isDeparting(toplevel) {
        void root.departingRevision;
        return !!toplevel && root.departing[root._address(toplevel)] === true;
    }
    function _setDeparting(toplevel, on) {
        const a = root._address(toplevel);
        const next = Object.assign({}, root.departing);
        if (on)
            next[a] = true;
        else
            delete next[a];
        root.departing = next;
        root.departingRevision++;
    }

    // Angeforderte, von Hyprland noch nicht bestätigte Fläche je Monitor ({ monitorName: id }). Übersicht und Leiste
    // gleiten sofort dorthin, statt auf das IPC-Ereignis zu warten; nach `pendingTimeout` ms ohne Bestätigung verfällt die Marke.
    property var pendingActive: ({})
    property int pendingRevision: 0
    readonly property int pendingTimeout: 800

    // Angeforderte Fläche des Monitors, -1 wenn keine aussteht
    function pendingFor(screen) {
        void root.pendingRevision;
        const mon = screen ? Hyprland.monitorFor(screen) : root.focusedMonitor;
        if (!mon)
            return -1;
        const id = root.pendingActive[mon.name];
        return id === undefined ? -1 : id;
    }
    function _setPending(mon, id) {
        const next = Object.assign({}, root.pendingActive);
        next[mon.name] = id;
        root.pendingActive = next;
        root.pendingRevision++;
        pendingTimer.restart();
    }
    Timer {
        id: pendingTimer
        interval: root.pendingTimeout
        onTriggered: {
            root.pendingActive = ({});
            root.pendingRevision++;
        }
    }

    // Fasst schnelle Ereignisfolgen (Öffnen, Verschieben, Größe) zu einer Abfrage zusammen
    Timer {
        id: geometryTimer
        interval: 30
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            root.geometryRevision++;
            clearDepartingTimer.restart();
        }
    }
    // Nach der Aktualisierung kennt Hyprland die neue Fläche des Fensters: die Marke wird nicht mehr gebraucht
    Timer {
        id: clearDepartingTimer
        interval: 250
        onTriggered: {
            root.departing = ({});
            root.departingRevision++;
        }
    }

    // Arbeitsflächen eines Monitors (QuickshellScreenInfo) in Anzeigereihenfolge:
    // [{ id, index (1-basiert), workspace (HyprlandWorkspace oder null für die leere Endfläche),
    //    windows: [HyprlandToplevel], active, urgent, empty }]
    function workspacesFor(screen) {
        const mon = screen ? Hyprland.monitorFor(screen) : root.focusedMonitor;
        if (!mon)
            return [];
        const all = Hyprland.workspaces.values.filter(w => w.id > 0);
        const mine = all.filter(w => w.monitor === mon && (w.toplevels.values.length > 0 || w.active || w.focused || w.lastIpcObject?.ispersistent)).sort((a, b) => a.id - b.id);
        const list = mine.map((w, i) => ({
                    id: w.id,
                    index: i + 1,
                    workspace: w,
                    windows: w.toplevels.values,
                    active: mon.activeWorkspace === w,
                    urgent: w.urgent,
                    empty: w.toplevels.values.length === 0
                }));
        // GNOME hält immer eine leere Fläche am Ende
        if (list.length === 0 || !list[list.length - 1].empty) {
            const next = all.reduce((m, w) => Math.max(m, w.id), 0) + 1;
            list.push({
                id: next,
                index: list.length + 1,
                workspace: null,
                windows: [],
                active: false,
                urgent: false,
                empty: true
            });
        }
        return list;
    }

    // Arbeitsflächen des fokussierten Monitors
    readonly property var workspaces: workspacesFor(null)

    function windowsOn(workspaceId) {
        return root.windows.filter(t => t.workspace && t.workspace.id === workspaceId);
    }

    // Zu Fläche wechseln; mit `screen` zuerst den Monitor fokussieren (nötig für neue, leere Flächen)
    function switchTo(id, screen) {
        const mon = screen ? Hyprland.monitorFor(screen) : root.focusedMonitor;
        if (mon)
            root._setPending(mon, id);
        if (mon && mon !== root.focusedMonitor)
            root._dispatch("focusmonitor " + mon.name, 'hl.dsp.focus({ monitor = "' + mon.name + '" })');
        root._dispatch("workspace " + id, "hl.dsp.focus({ workspace = " + id + " })");
    }
    function switchRelative(delta, screen) {
        // Auf den belegten Flächen des Monitors, wie Strg+Alt+Pfeil in GNOME. Ausgangspunkt ist eine noch
        // ausstehende Anforderung, damit schnelles Scrollen mehrere Flächen weit kommt.
        const list = screen ? root.workspacesFor(screen) : root.workspaces;
        const pending = root.pendingFor(screen);
        const pendingIndex = pending >= 0 ? list.findIndex(w => w.id === pending) : -1;
        const cur = pendingIndex >= 0 ? pendingIndex : list.findIndex(w => w.active);
        const target = list[Math.max(0, Math.min(list.length - 1, cur + delta))];
        if (target && cur >= 0 && target.id !== list[cur].id)
            root.switchTo(target.id, screen);
    }
    // Monitor fokussieren (neue Flächen entstehen auf dem fokussierten Monitor)
    function focusMonitor(screen) {
        const mon = screen ? Hyprland.monitorFor(screen) : null;
        if (mon && mon !== root.focusedMonitor)
            root._dispatch("focusmonitor " + mon.name, 'hl.dsp.focus({ monitor = "' + mon.name + '" })');
    }

    // Zeitpunkt (ms) der letzten Fokus-Anforderung für ein Fenster (OverviewService.hide überschreibt sie nicht)
    property double lastFocusRequest: 0

    function focusWindow(toplevel) {
        if (toplevel) {
            root.lastFocusRequest = Date.now();
            const a = root._address(toplevel);
            root._dispatch("focuswindow address:" + a, 'hl.dsp.focus({ window = "address:' + a + '" })');
        }
    }
    // Fenster über seine Hyprland-Adresse fokussieren (wechselt bei Bedarf die Arbeitsfläche)
    function focusAddress(address) {
        const a = address.startsWith("0x") ? address : "0x" + address;
        root.lastFocusRequest = Date.now();
        root._dispatch("focuswindow address:" + a, 'hl.dsp.focus({ window = "address:' + a + '" })');
    }
    function closeWindow(toplevel) {
        if (toplevel) {
            const a = root._address(toplevel);
            root._dispatch("closewindow address:" + a, 'hl.dsp.window.close({ window = "address:' + a + '" })');
        }
    }
    // Fenster auf Fläche verschieben; follow = mitwechseln
    function moveWindow(toplevel, id, follow) {
        if (!toplevel)
            return;
        const a = root._address(toplevel);
        if (!follow)
            root._setDeparting(toplevel, true);
        root._dispatch((follow ? "movetoworkspace " : "movetoworkspacesilent ") + id + ",address:" + a, "hl.dsp.window.move({ workspace = " + id + ", follow = " + (follow ? "true" : "false") + ', window = "address:' + a + '" })');
    }

    // App starten und ihr erstes neues Fenster still auf Fläche `id` schieben (App aus dem App-Grid auf eine Vorschau
    // gezogen). Das Fenster wird über das openwindow-Ereignis erkannt; nach 15 s verfällt die Anforderung.
    property var _pendingLaunches: []
    function launchOn(entry, id) {
        if (!entry)
            return;
        root._pendingLaunches = root._pendingLaunches.concat([
            {
                "id": entry.id.toLowerCase(),
                "startupClass": (entry.startupClass || "").toLowerCase(),
                "workspace": id,
                "deadline": Date.now() + 15000
            }
        ]);
        AppsService.launch(entry);
    }
    // data: "adresse,fläche,klasse,titel"
    function _claimOpenedWindow(data) {
        const now = Date.now();
        const pending = root._pendingLaunches.filter(p => p.deadline > now);
        if (pending.length === 0) {
            root._pendingLaunches = pending;
            return;
        }
        const parts = data.split(",");
        const cls = (parts[2] ?? "").toLowerCase();
        const i = pending.findIndex(p => cls !== "" && (p.id === cls || (p.startupClass !== "" && p.startupClass === cls)));
        if (i < 0) {
            root._pendingLaunches = pending;
            return;
        }
        const target = pending.splice(i, 1)[0];
        root._pendingLaunches = pending;
        const a = parts[0].startsWith("0x") ? parts[0] : "0x" + parts[0];
        root._dispatch("movetoworkspacesilent " + target.workspace + ",address:" + a, "hl.dsp.window.move({ workspace = " + target.workspace + ', follow = false, window = "address:' + a + '" })');
    }

    // Hyprland mit Lua-Konfiguration erwartet Lua-Ausdrücke, sonst die klassischen Dispatcher
    function _dispatch(classic, lua) {
        Hyprland.dispatch(root.usingLua ? lua : classic);
    }

    function _address(toplevel) {
        return toplevel.address.startsWith("0x") ? toplevel.address : "0x" + toplevel.address;
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            root.event(e.name, e.data);
            if (e.name === "openwindow")
                root._claimOpenedWindow(e.data);
            if (e.name === "workspace" || e.name === "workspacev2" || e.name === "focusedmon" || e.name === "moveworkspace" || e.name === "activespecial")
                root.revision++;
            // Titel- und Fokuswechsel ändern keine Geometrie: sie kommen bei Terminals und Browsern ständig und
            // lösten sonst bei offener Übersicht laufend ein neues Layout aller Flächen aus
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "fullscreen", "changefloatingmode", "resizewindow", "moveworkspace", "workspacev2", "createworkspacev2", "destroyworkspacev2"].indexOf(e.name) >= 0)
                geometryTimer.restart();
        }
    }
}
