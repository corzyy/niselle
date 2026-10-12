pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Einstellungen der Shell. Alles liegt in einer JSON-Datei unter Quickshell.statePath("settings.json"); es gibt keine
// Abhängigkeit von gsettings/dconf. Hell/Dunkel, Flugmodus, Nicht stören und Gamemode sind Zustände mit
// eigenen Funktionen; die übrigen Werte (Uhr, Kalender, Hintergrund, Standard-Apps) werden über `set(key, value)` geschrieben.
Singleton {
    id: root

    // Einstellungen sind immer nutzbar (lokale Datei); false erst, wenn die Datei nicht schreibbar ist
    readonly property bool available: !_saveFailed
    // Datei wurde gelesen (oder neu angelegt)
    readonly property bool loaded: _loaded

    property bool darkMode: true
    // Flugmodus: rfkill block/unblock all, Zustand per `rfkill event`
    property bool airplaneMode: false
    // Nicht stören = Banner aus
    property bool doNotDisturb: false
    // Gamemode: Hyprland- und Shell-Blur sowie alle Animationen aus (siehe GameModeService/Theme.gameMode)
    property bool gameMode: false
    // BigYahoo: ersetzt jedes Symbol in der Shell durch die israelische Flagge (siehe components/Icon.qml)
    property bool bigYahoo: false

    // Primäranzeige (Monitor mit Leiste und Aktivitäten), Name des Monitors
    readonly property string primaryDisplay: store.primaryDisplay ?? ""
    // Gespeicherte Anzeigenzuweisung (siehe DisplayService): { mode, outputs: { name: {…} } }
    readonly property var displays: store.displays ?? ({})

    // Uhr und Akku in der Leiste
    readonly property bool clock12h: store.clock12h
    readonly property bool showBatteryPercentage: store.showBatteryPercentage
    // Aktives Fenster (Icon und Name) in der Leiste zeigen; Leiste ohne Hintergrund
    readonly property bool transparentBar: store.transparentBar
    // Panels (Datumsmenü, Systemmenü) hängen direkt unter ihrem Leisten-Element und wandern mit, wenn es die Zone wechselt
    readonly property bool barPanelsFollowItems: store.barPanelsFollowItems ?? true
    // Menüleiste: Uhr ("dateTime" | "time" | "date"), Arbeitsflächen ("dots" | "numbers"), aktive App, Symbole der Systempille
    readonly property string barClockFormat: store.barClockFormat ?? "dateTime"
    readonly property string barWorkspaceStyle: store.barWorkspaceStyle ?? "dots"
    readonly property bool barAppShowIcon: store.barAppShowIcon ?? true
    readonly property bool barAppShowName: store.barAppShowName ?? true
    readonly property bool barShowNetwork: store.barShowNetwork ?? true
    readonly property bool barShowBluetooth: store.barShowBluetooth ?? true
    readonly property bool barShowVolume: store.barShowVolume ?? true
    // Statusanzeigen der Leiste: Datenschutz (Kamera, Mikrofon, Standort), Netzwerk-/Systemstatus (VPN, USB-Tethering,
    // Flugmodus, Thunderbolt)
    readonly property bool showPrivacyIndicators: store.showPrivacyIndicators
    readonly property bool showStatusIndicators: store.showStatusIndicators
    // Übersicht: Fenster-Kacheln live (Screencopy-Stream) statt eines einzelnen Standbilds
    readonly property bool overviewLiveWindows: store.overviewLiveWindows ?? true
    // Dash/Dock: größte Icongröße (px), dauerhaft am unteren Rand sichtbar (sonst nur in der Übersicht), mit Autohide
    readonly property int dockIconSize: store.dockIconSize
    readonly property bool dockPersistent: store.dockPersistent
    readonly property bool dockAutohide: store.dockAutohide
    // Energie: Sperren und Standby nach Leerlauf (Sekunden), Sperren vor dem Standby (siehe IdleService)
    readonly property bool idleLockEnabled: store.idleLockEnabled
    readonly property int idleLockDelay: store.idleLockDelay
    readonly property bool idleSuspendEnabled: store.idleSuspendEnabled
    readonly property int idleSuspendDelay: store.idleSuspendDelay
    readonly property bool lockBeforeSuspend: store.lockBeforeSuspend
    // Suche: abgeschaltete Anbieter (IDs aus SearchService.allProviders) und Zwischenablage-Verlauf (cliphist)
    readonly property var searchDisabled: store.searchDisabled ?? []
    readonly property bool clipboardHistory: store.clipboardHistory
    // Kalender: Wochennummern zeigen; Wochenstart 0 = Sonntag … 6 = Samstag, -1 = nach Locale
    readonly property bool showWeekNumbers: store.showWeekNumbers
    readonly property int weekStart: store.weekStart

    // Farben aus der Matugen-Palette (Theme.paletteFile) statt der festen GNOME-Farben; Schemaart für `matugen -t`
    readonly property bool useMatugen: store.useMatugen
    readonly property string matugenScheme: store.matugenScheme

    // Schriftfamilien der Shell (leer = Standard: Adwaita Sans / Adwaita Mono)
    readonly property string fontFamily: store.fontFamily
    readonly property string fontFamilyMono: store.fontFamilyMono

    // Hintergrundbild (Pfad oder file://-URL) für die Übersicht, wenn awww nichts meldet; …Dark für den dunklen Stil
    readonly property string wallpaper: store.wallpaper
    readonly property string wallpaperDark: store.wallpaperDark
    // Zuletzt über die Einstellungen gesetzte Hintergrundbilder (Pfade), neuestes zuerst
    readonly property var wallpaperHistory: store.wallpaperHistory ?? []

    // Anwendungen, die ein Klick im Datumsmenü startet: { calendar } = Desktop-Datei-ID; leer = nicht klickbar
    readonly property var defaultApps: store.defaultApps ?? ({})

    // Aufbau des Datumsmenüs [GNOME-Mockup calendar-popover]
    //   calendarLayout:            "auto" (zweispaltig, sobald Termine sichtbar sind), "single" oder "split"
    //   calendarShowDateHeader:    Wochentag und Datum über den Terminen (zweispaltig)
    //   calendarShowEvents:        Termine ein- und ausblenden
    //   calendarUpcomingOnly:      nur noch anstehende Termine des heutigen Tages
    readonly property string calendarLayout: store.calendarLayout
    readonly property bool calendarShowDateHeader: store.calendarShowDateHeader
    readonly property bool calendarShowEvents: store.calendarShowEvents
    readonly property bool calendarUpcomingOnly: store.calendarUpcomingOnly

    // Sperrbildschirm: Aussehen von Uhr und Datum (siehe components/LockClock.qml und LockscreenPage).
    //   lockClockStyle:    "inline" | "stacked" | "minimal" | "mono"
    //   lockClockSize:     "s" | "m" | "l" | "xl"
    //   lockClockWeight:   "light" | "regular" | "bold" | "extra"
    //   lockClockPosition: "top" | "upper" | "center" | "lower"
    //   lockClockColor:    "auto" (weiß) | "accent"
    //   lockDateFormat:    "long" | "full" | "short" | "numeric" | "weekday" | "none"
    //   lockDateUppercase, lockShowHint, lockBlurCurtain (Vorhang unscharf wie der Dialog)
    readonly property string lockClockStyle: store.lockClockStyle ?? "inline"
    readonly property string lockClockSize: store.lockClockSize ?? "l"
    readonly property string lockClockWeight: store.lockClockWeight ?? "extra"
    readonly property string lockClockPosition: store.lockClockPosition ?? "upper"
    readonly property string lockClockColor: store.lockClockColor ?? "auto"
    readonly property string lockDateFormat: store.lockDateFormat ?? "long"
    readonly property bool lockDateUppercase: store.lockDateUppercase ?? false
    readonly property bool lockShowHint: store.lockShowHint ?? true
    readonly property bool lockBlurCurtain: store.lockBlurCurtain ?? false

    // Hyprland-Blur hinter allen Shell-Flächen (Leiste, Dock, Popups, Dialoge, OSD ...), siehe BlurService
    readonly property bool shellBlur: store.shellBlur ?? true

    // Kompaktere Shell (Leiste, Benachrichtigungen, OSD, Quick-Settings, Einstellungen)
    readonly property bool compact: store.compact ?? false

    // Menüleiste: Elemente und ihre Zonen. `barLayout` = { left, center, right } mit IDs aus `barItems`; nicht gelistete
    // Elemente sind ausgeblendet. Die Quick-Settings-Pille ist Pflicht (sonst gäbe es keinen Zugang) und wird bei Bedarf rechts ergänzt.
    readonly property var barItems: [
        {
            "id": "workspaces",
            "title": "Workspaces",
            "icon": "view-grid-symbolic"
        },
        {
            "id": "activeWindow",
            "title": "Active Window",
            "icon": "preferences-system-windows-symbolic"
        },
        {
            "id": "clock",
            "title": "Clock",
            "icon": "preferences-system-time-symbolic"
        },
        {
            "id": "keyboard",
            "title": "Keyboard Layout",
            "icon": "input-keyboard-symbolic"
        },
        {
            "id": "status",
            "title": "System Menu & Recording",
            "icon": "emblem-system-symbolic",
            "required": true
        }
    ]
    readonly property var defaultBarLayout: ({
            "left": ["workspaces", "activeWindow"],
            "center": ["clock"],
            "right": ["keyboard", "status"]
        })
    readonly property var barLayout: _normalizeBarLayout(barStore.layout)

    function _normalizeBarLayout(raw) {
        // Aus der JSON-Datei geladene Listen sind keine echten JS-Arrays (Array.isArray ist false) – erst normalisieren
        raw = raw ? JSON.parse(JSON.stringify(raw)) : raw;
        const src = raw && (raw.left || raw.center || raw.right) ? raw : root.defaultBarLayout;
        const known = root.barItems.map(i => i.id);
        const seen = [];
        const out = {};
        for (const zone of ["left", "center", "right"]) {
            out[zone] = (Array.isArray(src[zone]) ? src[zone] : []).filter(id => {
                if (known.indexOf(id) < 0 || seen.indexOf(id) >= 0)
                    return false;
                seen.push(id);
                return true;
            });
        }
        for (const item of root.barItems) {
            if (item.required && seen.indexOf(item.id) < 0)
                out.right.push(item.id);
        }
        return out;
    }

    // Zone eines Elements ("left", "center", "right") oder "" (ausgeblendet)
    function barZoneOf(id) {
        for (const zone of ["left", "center", "right"]) {
            if (root.barLayout[zone].indexOf(id) >= 0)
                return zone;
        }
        return "";
    }
    // Element in `zone` an Position `index` setzen; zone "" blendet es aus (nicht für Pflichtelemente)
    function moveBarItem(id, zone, index) {
        const item = root.barItems.find(i => i.id === id);
        if (!item || (zone === "" && item.required))
            return;
        const next = {};
        for (const z of ["left", "center", "right"])
            next[z] = root.barLayout[z].filter(x => x !== id);
        if (zone !== "")
            next[zone].splice(Math.max(0, Math.min(index ?? next[zone].length, next[zone].length)), 0, id);
        barStore.layout = next;
    }
    function resetBarLayout() {
        barStore.layout = ({});
    }

    // Kacheln der Quick-Settings in Anzeigereihenfolge (IDs aus QuickSettings.tileCatalog); nicht gelistete Kacheln sind ausgeblendet
    // Das frühere "wifi" ist in "network" aufgegangen; alte Listen werden beim Laden umgeschrieben
    readonly property var quickToggles: _normalizeQuickToggles(store.quickToggles ?? defaultQuickToggles)
    readonly property var defaultQuickToggles: ["network", "bluetooth", "profile", "performance", "gamemode", "dark", "airplane", "dnd", "caffeine", "keyboard", "bigyahoo"]

    function _normalizeQuickToggles(list) {
        const out = [];
        for (const raw of list) {
            const id = raw === "wifi" ? "network" : raw;
            if (out.indexOf(id) < 0)
                out.push(id);
        }
        return out;
    }

    function addQuickToggle(id) {
        if (root.quickToggles.indexOf(id) < 0)
            store.quickToggles = root.quickToggles.concat([id]);
    }
    function removeQuickToggle(id) {
        store.quickToggles = root.quickToggles.filter(t => t !== id);
    }
    // Kachel an Position `index` der Liste verschieben
    function moveQuickToggle(id, index) {
        const list = root.quickToggles.filter(t => t !== id);
        if (list.length === root.quickToggles.length)
            return;
        list.splice(Math.max(0, Math.min(index, list.length)), 0, id);
        store.quickToggles = list;
    }

    // Flugmodus kommt aus rfkill
    readonly property bool airplaneModeSynced: _rfkillWorks

    // Beliebigen gespeicherten Wert setzen (clock12h, showBatteryPercentage, showWeekNumbers, weekStart, wallpaper,
    // wallpaperDark, wallpaperHistory, quickToggles, defaultApps, calendar*)
    readonly property var keys: ["darkMode", "doNotDisturb", "gameMode", "bigYahoo", "quickToggles", "useMatugen", "matugenScheme", "fontFamily", "fontFamilyMono", "clock12h", "showBatteryPercentage", "transparentBar", "barPanelsFollowItems", "barLayout", "barClockFormat", "barWorkspaceStyle", "barAppShowIcon", "barAppShowName", "barShowNetwork", "barShowBluetooth", "barShowVolume", "showPrivacyIndicators", "showStatusIndicators", "overviewLiveWindows", "dockIconSize", "dockPersistent", "dockAutohide", "showWeekNumbers", "weekStart", "wallpaper", "wallpaperDark", "wallpaperHistory", "defaultApps", "calendarLayout", "calendarShowDateHeader", "calendarShowEvents", "calendarUpcomingOnly", "lockClockStyle", "lockClockSize", "lockClockWeight", "lockClockPosition", "lockClockColor", "lockDateFormat", "lockDateUppercase", "lockShowHint", "lockBlurCurtain", "shellBlur", "compact", "idleLockEnabled", "idleLockDelay", "idleSuspendEnabled", "idleSuspendDelay", "lockBeforeSuspend", "searchDisabled", "clipboardHistory", "primaryDisplay", "displays"]

    function set(key, value) {
        if (root.keys.indexOf(key) < 0)
            return false;
        if (key === "darkMode")
            root.darkMode = value;
        else if (key === "doNotDisturb")
            root.doNotDisturb = value;
        else if (key === "gameMode")
            root.gameMode = value;
        else if (key === "bigYahoo")
            root.bigYahoo = value;
        else if (key === "barLayout")
            barStore.layout = value;
        else
            store[key] = value;
        return true;
    }

    // quickshell ipc call config set <key> <json-wert> | get <key> | list
    IpcHandler {
        target: "config"

        function set(key: string, value: string): string {
            let v = value;
            try {
                v = JSON.parse(value);
            } catch (e) {}
            return root.set(key, v) ? "ok" : "unknown key: " + key;
        }
        function get(key: string): string {
            return root.keys.indexOf(key) < 0 ? "unknown key: " + key : JSON.stringify(key === "darkMode" ? root.darkMode : key === "doNotDisturb" ? root.doNotDisturb : key === "gameMode" ? root.gameMode : key === "bigYahoo" ? root.bigYahoo : store[key]);
        }
        function list(): string {
            return root.keys.join("\n");
        }
    }

    function setDarkMode(on) {
        root.darkMode = on;
    }
    function setAirplaneMode(on) {
        root.airplaneMode = on;
    }
    function setDoNotDisturb(on) {
        root.doNotDisturb = on;
    }
    function setGameMode(on) {
        root.gameMode = on;
    }
    function setBigYahoo(on) {
        root.bigYahoo = on;
    }
    function toggleDarkMode() {
        root.darkMode = !root.darkMode;
    }
    function toggleAirplaneMode() {
        root.airplaneMode = !root.airplaneMode;
    }
    function toggleDoNotDisturb() {
        root.doNotDisturb = !root.doNotDisturb;
    }
    function toggleGameMode() {
        root.gameMode = !root.gameMode;
    }
    function toggleBigYahoo() {
        root.bigYahoo = !root.bigYahoo;
    }

    property bool _loaded: false
    property bool _saveFailed: false
    property bool _rfkillWorks: false

    // ───────── Persistenz ─────────

    // Menüleisten-Layout (left/center/right) in eigener Datei mit festem Pfad: statePath hängt vom Shell-Hash ab und
    // wird nach jedem Shell-Update zu einer neuen, leeren Datei; so bleibt das Layout über Updates und Neustarts erhalten.
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/niselle/menubar.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => writeAdapter()
        adapter: JsonAdapter {
            id: barStore
            property var layout: ({})
        }
    }

    FileView {
        id: file
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root._loaded = true;
            root.darkMode = store.darkMode;
            root.airplaneMode = store.airplaneMode;
            root.doNotDisturb = store.doNotDisturb;
            root.gameMode = store.gameMode;
            root.bigYahoo = store.bigYahoo;
        }
        onLoadFailed: error => {
            // Erststart: Datei mit Standardwerten anlegen
            root._loaded = true;
            writeAdapter();
        }
        onSaveFailed: root._saveFailed = true
        onSaved: root._saveFailed = false

        adapter: JsonAdapter {
            id: store
            property bool darkMode: true
            property bool airplaneMode: false
            property bool doNotDisturb: false
            property bool gameMode: false
            property bool bigYahoo: false
            property string primaryDisplay: ""
            property var displays: ({})
            property var quickToggles: ["network", "bluetooth", "profile", "performance", "gamemode", "dark", "airplane", "dnd", "caffeine", "keyboard", "bigyahoo"]
            property bool useMatugen: true
            property string matugenScheme: "scheme-tonal-spot"
            property string fontFamily: ""
            property string fontFamilyMono: ""
            property bool clock12h: false
            property bool showBatteryPercentage: false
            property var barLayout: ({})
            property string barClockFormat: "dateTime"
            property string barWorkspaceStyle: "dots"
            property bool barAppShowIcon: true
            property bool barAppShowName: true
            property bool barShowNetwork: true
            property bool barShowBluetooth: true
            property bool barShowVolume: true
            property bool transparentBar: true
            property bool barPanelsFollowItems: true
            property bool showPrivacyIndicators: true
            property bool showStatusIndicators: true
            property bool overviewLiveWindows: true
            property int dockIconSize: 48
            property bool dockPersistent: false
            property bool dockAutohide: true
            property bool showWeekNumbers: false
            property int weekStart: -1
            property string wallpaper: ""
            property string wallpaperDark: ""
            property var wallpaperHistory: []
            property var defaultApps: ({})
            property string calendarLayout: "auto"
            property bool calendarShowDateHeader: true
            property bool calendarShowEvents: true
            property bool calendarUpcomingOnly: true
            property string lockClockStyle: "inline"
            property string lockClockSize: "l"
            property string lockClockWeight: "extra"
            property string lockClockPosition: "upper"
            property string lockClockColor: "auto"
            property string lockDateFormat: "long"
            property bool lockDateUppercase: false
            property bool lockShowHint: true
            property bool lockBlurCurtain: false
            property bool shellBlur: true
            property bool compact: false
            property bool idleLockEnabled: true
            property int idleLockDelay: 300
            property bool idleSuspendEnabled: false
            property int idleSuspendDelay: 1800
            property bool lockBeforeSuspend: true
            property var searchDisabled: []
            property bool clipboardHistory: true
        }
    }

    onDarkModeChanged: store.darkMode = darkMode
    onDoNotDisturbChanged: store.doNotDisturb = doNotDisturb
    onGameModeChanged: store.gameMode = gameMode
    onBigYahooChanged: store.bigYahoo = bigYahoo
    onAirplaneModeChanged: {
        store.airplaneMode = airplaneMode;
        if (root._rfkillWorks && airplaneMode !== root._rfkillBlocked) {
            rfkillSet.command = ["rfkill", airplaneMode ? "block" : "unblock", "all"];
            rfkillSet.running = true;
        }
    }

    // ───────── Flugmodus (rfkill) ─────────

    property bool _rfkillBlocked: false

    // Auswertung der Radio-Liste: Flugmodus, wenn mindestens ein Funkgerät existiert und alle soft- oder hardgesperrt sind
    Process {
        id: rfkillList
        command: ["rfkill", "--noheadings", "--raw", "--output", "TYPE,SOFT,HARD"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n").filter(l => l.length > 0).map(l => l.split(" "));
                root._rfkillWorks = rows.length > 0;
                const blocked = rows.length > 0 && rows.every(r => r[1] === "blocked" || r[2] === "blocked");
                root._rfkillBlocked = blocked;
                if (rows.length > 0 && root.airplaneMode !== blocked)
                    root.airplaneMode = blocked;
            }
        }
    }

    Process {
        id: rfkillSet
    }

    // Eine Zeile pro rfkill-Änderung → Liste neu einlesen. Läuft nur, solange rfkill existiert.
    Process {
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser {
            onRead: rfkillList.running = true
        }
    }

    Component.onCompleted: rfkillList.running = true
}
