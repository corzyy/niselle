pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// Zustand der Übersicht (Overview) [overview.js]. Eine Übersicht für alle Monitore:
// `shown` ist das Ziel (Öffnen/Schließen), `progress` läuft 0 → 1 und treibt alle Animationen
// (ControlsState.HIDDEN → WINDOW_PICKER [overviewControls.js:718-749]): Öffnen 250 ms EASE_OUT_SINE, Schließen 250 ms EASE_OUT_QUAD.
//
// Auslöser: Super (globales Kürzel `niselle:overview` oder `quickshell ipc call overview toggle`), Aktivitäten-Knopf,
// heiße Ecke. Esc, Super und Klick ins Leere schließen im Overview-Fenster.
Singleton {
    id: root

    // Übersicht soll offen sein
    property bool shown: false
    // Fortschritt der Animation: 0 = Fenster in voller Größe, 1 = Übersicht komplett
    property real progress: 0
    // App-Grid statt Fensterbereich (Knopf „Apps anzeigen“ im Dash, ShowAppsButton.checked [overviewControls.js:394-420])
    property bool appsShown: false
    // Übergang Fensterbereich (0) ↔ App-Grid (1): 250 ms EASE_OUT_SINE [overviewControls.js:408-419, SIDE_CONTROLS_ANIMATION_TIME]
    property real appsProgress: 0
    // Übergang Fenster/App-Grid (0) ↔ Suchergebnisse (1): 250 ms EASE_OUT_QUAD [overviewControls.js:606-641]
    property real searchProgress: 0
    readonly property bool searchActive: SearchService.active
    // Geöffneter App-Ordner (Dialog über der Übersicht), leer = keiner
    property string openFolderId: ""

    // Fenster-Kachel, die gerade gezogen wird: die Quell-Übersicht meldet Monitor und globalen Zeigerpunkt,
    // die Übersichten der anderen Monitore zeichnen damit eine Kachel unter dem Zeiger.
    property bool windowDragActive: false
    property string windowDragScreen: ""
    property point windowDragPoint: Qt.point(0, 0)
    property size windowDragSize: Qt.size(0, 0)
    property string windowDragIcon: ""
    property string windowDragTitle: ""

    // Eine App wurde aus einem Ordner auf den Hintergrund gezogen: das App-Grid setzt sie an die
    // Ablegestelle (Fensterkoordinaten) [appDisplay.js: AppDisplay.acceptDrop, _ensurePlaceholder]
    signal appDroppedInGrid(string appId, real x, real y)

    // Rechteck der aktiven Arbeitsflächen-Vorschau (Fensterkoordinaten des primären Monitors).
    // Setzt WorkspaceThumbnails; WindowPicker lässt die Fenster beim Öffnen des App-Grids dorthin schrumpfen.
    property rect activeThumbnailRect: Qt.rect(0, 0, 0, 0)
    // Mitte des „Apps anzeigen“-Knopfs (Fensterkoordinaten). Setzt ShowAppsButton; das App-Grid wächst von dort auf.
    property point appsOrigin: Qt.point(0, 0)

    // Beim Schließen erneut anzufordernde Arbeitsflächen ([{ monitor, id }], siehe hide())
    property var _restoreWorkspaces: []
    // Fläche des primären Monitors beim Öffnen: nur wenn sie sich in der Übersicht geändert hat, muss sie
    // beim Schließen wiederhergestellt werden
    property int _openWorkspaceId: -1

    // Fenster-Standbilder (ScreencopyView) bleiben auch bei geschlossener Übersicht erhalten: beim Öffnen ist
    // sofort das zuletzt aufgenommene Bild da (wie die Fenster-Klone in GNOME), statt einer leeren Kachel.
    // `refreshCaptures(activeOnly)` fordert neue Bilder an: beim Öffnen sofort für die Fenster der aktiven Flächen,
    // die übrigen nach der Öffnungsanimation (viele Aufnahmen während der Animation ließen sie ruckeln).
    // `captureArmed` gibt nach der Animation den Live-Stream frei (Einstellung overviewLiveWindows).
    property bool captureArmed: false
    signal refreshCaptures(bool activeOnly)
    Timer {
        id: armTimer
        interval: Theme.gameMode ? 0 : Theme.durationOverview
        onTriggered: {
            if (!root.shown)
                return;
            root.captureArmed = true;
            root.refreshCaptures(false);
        }
    }
    onVisibleChanged: {
        if (!root.visible) {
            armTimer.stop();
            root.captureArmed = false;
            root._restoreWorkspaceAnimations();
        }
    }

    // Hyprland gibt Vollbild-Fenster direkt aus (direct_scanout), lässt sie reißen (allow_tearing) oder nutzt VRR.
    // Dann darf über einem Vollbild-Fenster keine (leere) Ebene der Übersicht liegen, sonst greift das nicht; die
    // Übersicht wird dort bei geschlossenem Zustand ausgeblendet und muss beim Öffnen erst angelegt werden.
    // Bis die Werte gelesen sind, gilt die vorsichtige Annahme.
    property bool scanoutSensitive: true
    Process {
        running: true
        command: ["sh", "-c", "for o in render:direct_scanout general:allow_tearing misc:vrr; do hyprctl getoption $o -j; echo; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                let sensitive = false;
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    try {
                        const o = JSON.parse(line);
                        if ((o.int ?? 0) !== 0 || o.bool === true)
                            sensitive = true;
                    } catch (e) {
                        sensitive = true;
                    }
                }
                root.scanoutSensitive = sensitive;
            }
        }
    }

    // ───────── Arbeitsflächen-Animation von Hyprland ─────────
    // Solange die Übersicht offen ist, gleitet sie selbst zwischen den Flächen; Hyprland würde den echten Wechsel
    // darunter zusätzlich animieren (unsichtbar, kostet aber GPU-Zeit). Beim Öffnen werden die aktuellen Werte gelesen
    // (`hyprctl animations -j`) und die Animation abgeschaltet, nach dem vollständigen Schließen exakt zurückgesetzt.
    // Die gelesenen Werte liegen in einer Datei: wird die Shell bei offener Übersicht neu geladen oder beendet, stellt
    // der nächste Start die Animation wieder her.
    readonly property var _workspaceLeaves: ["workspaces", "workspacesIn", "workspacesOut"]
    readonly property var _savedAnimations: animStore.saved
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/niselle/workspace-animations.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            if (!root.shown)
                root._restoreWorkspaceAnimations();
        }
        adapter: JsonAdapter {
            id: animStore
            property var saved: []
        }
    }
    Process {
        id: animQuery
        command: ["hyprctl", "animations", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root._disableWorkspaceAnimations(text)
        }
    }
    function _disableWorkspaceAnimations(text) {
        if (!root.shown || (root._savedAnimations && root._savedAnimations.length > 0))
            return;
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return;
        }
        const list = (Array.isArray(data) && Array.isArray(data[0])) ? data[0] : [];
        const saved = list.filter(a => root._workspaceLeaves.indexOf(a.name) >= 0 && a.enabled);
        if (saved.length === 0)
            return;
        animStore.saved = saved;
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "eval", saved.map(a => 'hl.animation({ leaf = "' + a.name + '", enabled = false })').join("; ")]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", saved.map(a => "keyword animation " + a.name + ",0").join(" ; ")]);
    }
    function _restoreWorkspaceAnimations() {
        const saved = root._savedAnimations;
        if (!saved || saved.length === 0)
            return;
        animStore.saved = [];
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "eval", saved.map(a => 'hl.animation({ leaf = "' + a.name + '", enabled = true, speed = ' + a.speed + ', bezier = "' + a.bezier + '"' + (a.style ? ', style = "' + a.style + '"' : "") + " })").join("; ")]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", saved.map(a => "keyword animation " + a.name + ",1," + a.speed + "," + a.bezier + (a.style ? "," + a.style : "")).join(" ; ")]);
    }

    function _primaryWorkspaceId() {
        const mon = Hyprland.monitors.values.find(m => m.name === Theme.primaryScreenName);
        return mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
    }

    // Rückfall: stellt nach dem Schließen die Fläche wieder her, falls Hyprland sie beim Freigeben des Fokus doch
    // zurückgesetzt hat (hide() fokussiert dafür vorab ein Fenster der Fläche; leere Flächen brauchen dies weiterhin)
    Timer {
        id: restoreTimer
        interval: 60
        onTriggered: {
            if (root.shown)
                return;
            for (const w of root._restoreWorkspaces) {
                if (root._primaryWorkspaceId() === w.id)
                    continue;
                const classic = "workspace " + w.id;
                const lua = 'hl.dsp.focus({ workspace = ' + w.id + ' })';
                Hyprland.dispatch(Hyprland.usingLua ? lua : classic);
            }
            root._restoreWorkspaces = [];
        }
    }

    // Zuletzt fokussiertes Fenster einer Fläche (Hyprland-IPC `lastwindow`), sonst das erste Fenster darauf
    function _lastWindowOf(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (!ws)
            return "";
        const wins = ws.toplevels.values;
        const last = ws.lastIpcObject?.lastwindow ?? "";
        const lastClean = last.replace(/^0x/, "");
        if (last !== "" && last !== "0x0" && wins.some(t => t.address.replace(/^0x/, "") === lastClean))
            return last;
        return wins.length > 0 ? wins[0].address : "";
    }

    // Mitte der geöffneten Ordner-Kachel (Fensterkoordinaten): der Dialog wächst von dort auf
    property point folderOrigin: Qt.point(-1, -1)
    function openFolder(id, origin) {
        if (origin)
            root.folderOrigin = origin;
        root.openFolderId = id;
    }
    function closeFolder() {
        root.openFolderId = "";
    }
    // Fenster sichtbar (offen oder noch in der Schließanimation)
    // `animating` hält es auch während der Feder, wenn `progress` durch das Überschwingen unter 0 fällt
    readonly property bool visible: shown || progress > 0 || animating
    readonly property bool animating: anim.running

    // Primärer Monitor: trägt Suche, Arbeitsflächen-Leiste und Dash; alle anderen zeigen nur den Fensterbereich
    // Bis DisplayService und Einstellungen den Monitor kennen, gibt es keinen (sonst entstehen Leiste und Übersicht erst auf dem falschen Monitor und werden neu gebaut)
    readonly property var primaryScreen: (Theme.primaryScreenName === "" && !(DisplayService.loaded && SettingsService.loaded)) ? null : Quickshell.screens.find(s => s.name === Theme.primaryScreenName) ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    function isPrimary(screen) {
        return !!screen && !!root.primaryScreen && screen.name === root.primaryScreen.name;
    }

    // Zeitpunkte (ms) des letzten Öffnens und der letzten Zustandsänderung
    property double activatedAt: 0
    property double changedAt: 0

    // `withApps`: gleich im App-Grid öffnen (Kürzel toggle-application-view) [overviewControls.js:448-456]
    function show(withApps) {
        if (root.shown)
            return;
        root.activatedAt = root.changedAt = Date.now();
        root.shown = true;
        // Fenstergeometrie frisch holen, damit die Arbeitsflächen-Vorschauen das echte Layout zeigen
        Hyprland.refreshToplevels();
        root._openWorkspaceId = root._primaryWorkspaceId();
        SearchService.reset();
        // Beim direkten Öffnen im App-Grid den Fortschritt von 0 starten, damit sich das Raster wie beim
        // Umschalten aus der Übersicht aus dem „Apps anzeigen“-Knopf heraus aufbaut (onAppsShownChanged).
        if (withApps === true) {
            root.appsProgress = 0;
            root.appsShown = true;
        }
        root._animate(1);
        // Gespeicherte Standbilder zeigen sofort; neue Bilder für die aktiven Flächen gleich, die übrigen und den
        // Live-Stream erst nach der Öffnungsanimation (siehe captureArmed)
        root.captureArmed = false;
        root.refreshCaptures(true);
        armTimer.restart();
        if (!Theme.gameMode && (!root._savedAnimations || root._savedAnimations.length === 0))
            animQuery.running = true;
    }
    // Übersicht mit vorgegebenem Suchtext öffnen (z. B. „clip “ für den Zwischenablage-Verlauf)
    function openSearch(text) {
        if (!root.shown)
            root.show();
        else if (root.appsShown)
            root.appsShown = false;
        SearchService.text = text;
    }
    function hide() {
        if (!root.shown)
            return;
        // Arbeitsfläche je Monitor merken: sie wird beim Schließen erneut angefordert (siehe restoreTimer).
        // Während die Übersicht den Tastaturfokus hält, wechselt der Fensterfokus nicht mit; beim
        // Freigeben setzt Hyprland ihn (und damit die Fläche) auf den Stand vor dem Öffnen zurück.
        // Nur der primäre Monitor hält den Tastaturfokus und setzt seine Fläche beim Schließen zurück.
        // Andere Monitore hier nicht anfassen: ein "workspace"-Dispatch auf einen fremden Monitor
        // fokussiert ihn und zieht den Mauszeiger dorthin.
        // Eine gerade angeforderte, noch unbestätigte Fläche zählt schon (schnell scrollen und sofort schließen)
        const pending = WorkspaceService.pendingFor(root.primaryScreen);
        const current = pending > 0 ? pending : root._primaryWorkspaceId();
        root._restoreWorkspaces = (current > 0 && current !== root._openWorkspaceId)
            ? [{
                    monitor: Theme.primaryScreenName,
                    id: current
                }] : [];
        // Ein Fenster der neuen Fläche fokussieren, bevor der Tastaturfokus der Übersicht frei wird: Hyprland kehrt dann
        // zu diesem Fenster zurück, statt zur alten Fläche zu springen und erst nach dem Rückfall-Timer (sichtbares Flackern)
        // wieder herzukommen.
        // Nicht, wenn gerade ein Fenster gewählt wurde (Klick auf eine Vorschau, Dash, Suche): das hat Vorrang.
        if (root._restoreWorkspaces.length > 0 && Date.now() - WorkspaceService.lastFocusRequest > 500) {
            const address = root._lastWindowOf(current);
            if (address !== "")
                WorkspaceService.focusAddress(address);
        }
        root.shown = false;
        root.appsShown = false;
        root.openFolderId = "";
        SearchService.reset();
        root.changedAt = Date.now();
        root._animate(0);
        restoreTimer.restart();
    }
    function toggle() {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // Knopf „Apps anzeigen“ und Super+A: beendet auch die Suche [searchController.js: _onShowAppsButtonToggled]
    function toggleApps() {
        if (!root.shown) {
            root.show(true);
            return;
        }
        SearchService.reset();
        root.appsShown = !root.appsShown;
    }

    // Esc: erst die Suche verlassen, dann den Ordner, dann das App-Grid, dann die Übersicht [searchController.js: _onStageKeyPress]
    function dismiss() {
        if (SearchService.active)
            SearchService.reset();
        else if (root.openFolderId !== "")
            root.closeFolder();
        else if (root.appsShown)
            root.appsShown = false;
        else
            root.hide();
    }

    onAppsShownChanged: {
        appsAnim.stop();
        appsAnim.to = root.appsShown ? 1 : 0;
        appsAnim.start();
    }
    onSearchActiveChanged: {
        searchAnim.stop();
        searchAnim.to = root.searchActive ? 1 : 0;
        searchAnim.start();
    }

    // Aktivitäten-Knopf und heiße Ecke [overview.js:436-447]: nicht während der Animation und nicht gleich nach dem Öffnen,
    // damit Ecke und Knopf zusammen nicht öffnen und sofort schließen
    function toggleByCornerOrButton() {
        if (root.animating)
            return;
        if (root.activatedAt > 0 && Date.now() - root.activatedAt < Theme.overviewActivationTimeout)
            return;
        root.toggle();
    }

    // Kürzel: Hyprland-Bind (beim Loslassen) und Tastaturereignis des Fensters können beide feuern
    function toggleByShortcut() {
        if (Date.now() - root.changedAt < Theme.overviewShortcutDebounce)
            return;
        root.toggle();
    }

    function _animate(to) {
        anim.stop();
        anim.from = root.progress;
        anim.to = to;
        anim.elapsed = 0;
        anim.start();
    }

    // Öffnen und Schließen: OutCubic statt OutQuint. OutQuint springt im ersten Frame schon weit (bei einem
    // verlorenen Frame beim Einblenden des Fensters sichtbar als Ruck); OutCubic startet sanfter und läuft weich aus.
    // Bildgetrieben statt nach der Uhr: Das Einblenden des Fensters und der erste Aufbau der Übersicht blockieren die
    // Oberfläche oft 100 ms und länger. Eine Uhr-Animation hätte in dieser Zeit schon den größten Teil ihrer 260 ms
    // verbraucht, und die Übersicht wäre ohne sichtbare Bewegung aufgesprungen. Hier zählt jedes gezeichnete Bild höchstens
    // `maxStep`: ein Aussetzer verlängert die Animation, statt sie zu verschlucken.
    FrameAnimation {
        id: anim

        readonly property real maxStep: 0.022
        property real from: 0
        property real to: 0
        property real elapsed: 0

        onTriggered: {
            const duration = Theme.gameMode ? 0 : Theme.durationOverview / 1000;
            elapsed += Math.min(frameTime, maxStep);
            const t = duration > 0 ? Math.min(1, elapsed / duration) : 1;
            root.progress = from + (to - from) * (1 - Math.pow(1 - t, 3));
            if (t >= 1)
                stop();
        }
    }

    NumberAnimation {
        id: appsAnim
        target: root
        property: "appsProgress"
        duration: Theme.gameMode ? 0 : Theme.durationAppGridReveal
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: searchAnim
        target: root
        property: "searchProgress"
        duration: Theme.gameMode ? 0 : Theme.motionMedium
        easing.type: Theme.easeEmphasized
    }

    // Super über das Kompositor-Protokoll. Hyprland: `bindr = SUPER, Super_L, global, niselle:overview`
    // bzw. Lua: hl.bind("SUPER + SUPER_L", hl.dsp.global("niselle:overview"), { release = true })
    GlobalShortcut {
        appid: "niselle"
        name: "overview"
        description: "Übersicht ein-/ausblenden"
        // Ein Bind mit `release = true` (der einzelne Super-Taste) meldet nur das Loslassen, ein normaler Bind nur das
        // Drücken. Beide lösen aus; kommen beide, verwirft die Entprellung in toggleByShortcut das zweite.
        onPressed: root.toggleByShortcut()
        onReleased: root.toggleByShortcut()
    }

    // Steuerung von außen (Tastenkürzel, Tests): quickshell ipc call overview toggle|open|close
    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggleByShortcut();
        }
        function open(): void {
            root.show();
        }
        function apps(): void {
            root.toggleApps();
        }
        function close(): void {
            root.hide();
        }
        function search(text: string): void {
            root.openSearch(text);
        }
    }

    // NISELLE_OVERVIEW=1 startet mit offener Übersicht (Entwicklungshilfe für die transparente Top Bar)
    Component.onCompleted: {
        if (Quickshell.env("NISELLE_OVERVIEW") === "1") {
            root.shown = true;
            root.progress = 1;
        }
        // NISELLE_APPS=1 öffnet zusätzlich das App-Grid
        if (Quickshell.env("NISELLE_APPS") === "1") {
            root.shown = true;
            root.progress = 1;
            root.appsProgress = 1;
            root.appsShown = true;
        }
    }
}
