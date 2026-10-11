pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Einstellungen der Shell. Alles liegt in einer JSON-Datei unter Quickshell.statePath("settings.json"); es gibt keine
// Abhängigkeit von gsettings/dconf. Hell/Dunkel, Nachtlicht, Flugmodus, Nicht stören und Gamemode sind Zustände mit
// eigenen Funktionen; die übrigen Werte (Uhr, Kalender, Hintergrund, Standard-Apps) werden über `set(key, value)` geschrieben.
Singleton {
    id: root

    // Einstellungen sind immer nutzbar (lokale Datei); false erst, wenn die Datei nicht schreibbar ist
    readonly property bool available: !_saveFailed
    // Datei wurde gelesen (oder neu angelegt)
    readonly property bool loaded: _loaded

    property bool darkMode: true
    property bool nightLight: false
    // Flugmodus: rfkill block/unblock all, Zustand per `rfkill event`
    property bool airplaneMode: false
    // Nicht stören = Banner aus
    property bool doNotDisturb: false
    // Gamemode: Hyprland- und Shell-Blur sowie alle Animationen aus (siehe GameModeService/Theme.gameMode)
    property bool gameMode: false
    // BigYahoo: ersetzt jedes Symbol in der Shell durch die israelische Flagge (siehe components/Icon.qml)
    property bool bigYahoo: false

    // Nachtlicht über hyprsunset oder wlsunset: "hyprsunset", "wlsunset" oder "" (nichts installiert)
    readonly property string nightLightBackend: _nightLightBackend
    // Nachtlicht lässt sich schalten (ein Werkzeug ist installiert)
    readonly property bool nightLightAvailable: _nightLightBackend !== ""
    // Farbtemperatur in Kelvin
    readonly property int nightLightTemperature: store.nightLightTemperature
    // Zeitplan: "automatic" (Sonnenunter- bis -aufgang) oder "manual"
    readonly property string nightLightSchedule: store.nightLightSchedule ?? "automatic"
    // Manuelle Zeiten als Stundenbruch (z. B. 20.5 = 20:30)
    readonly property real nightLightFrom: store.nightLightFrom
    readonly property real nightLightTo: store.nightLightTo
    // Primäranzeige (Monitor mit Leiste und Aktivitäten), Name des Monitors
    readonly property string primaryDisplay: store.primaryDisplay ?? ""
    // Gespeicherte Anzeigenzuweisung (siehe DisplayService): { mode, outputs: { name: {…} } }
    readonly property var displays: store.displays ?? ({})

    // Uhr und Akku in der Leiste
    readonly property bool clock12h: store.clock12h
    readonly property bool showBatteryPercentage: store.showBatteryPercentage
    // Aktives Fenster (Icon und Name) in der Leiste zeigen; Leiste ohne Hintergrund
    readonly property bool transparentBar: store.transparentBar
    // Menüleiste: Uhr ("dateTime" | "time" | "date"), Arbeitsflächen ("dots" | "numbers"), aktive App, Symbole der Systempille
    readonly property string barClockFormat: store.barClockFormat ?? "dateTime"
    readonly property string barWorkspaceStyle: store.barWorkspaceStyle ?? "dots"
    // Systemaktualisierungen (UpdateService): automatisch prüfen, Abstand in Stunden
    readonly property bool updatesAutoCheck: store.updatesAutoCheck ?? true
    readonly property int updatesCheckHours: store.updatesCheckHours ?? 3
    readonly property bool barVitalsCpu: store.barVitalsCpu ?? true
    readonly property bool barVitalsMemory: store.barVitalsMemory ?? true
    readonly property bool barVitalsTemp: store.barVitalsTemp ?? true
    readonly property bool barVitalsNet: store.barVitalsNet ?? false
    readonly property int barVisualizerBars: store.barVisualizerBars ?? 12
    readonly property bool barAppShowIcon: store.barAppShowIcon ?? true
    readonly property bool barAppShowName: store.barAppShowName ?? true
    readonly property bool barShowNetwork: store.barShowNetwork ?? true
    readonly property bool barShowBluetooth: store.barShowBluetooth ?? true
    readonly property bool barShowVolume: store.barShowVolume ?? true
    // Statusanzeigen der Leiste: Datenschutz (Kamera, Mikrofon, Standort), Netzwerk-/Systemstatus (VPN, USB-Tethering,
    // Flugmodus, Nachtlicht, Thunderbolt) und das Menü für Barrierefreiheit
    readonly property bool showPrivacyIndicators: store.showPrivacyIndicators
    readonly property bool showStatusIndicators: store.showStatusIndicators
    // Barrierefreiheit: größere Schrift, Animationen aus, Bildschirmleser (Orca)
    readonly property bool a11yLargeText: store.a11yLargeText
    readonly property bool a11yReduceMotion: store.a11yReduceMotion
    readonly property bool a11yScreenReader: store.a11yScreenReader
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

    // Anwendungen, die ein Klick im Datumsmenü startet: { calendar, weather, clocks } = Desktop-Datei-ID; leer = nicht klickbar
    readonly property var defaultApps: store.defaultApps ?? ({})

    // Optionale Module im Datumsmenü; leer = Abschnitt ausgeblendet.
    //   worldClocks:     [{ "name": "Tokio", "timezone": "Asia/Tokyo" }, …]
    //   weatherLocation: { "name": "Berlin", "latitude": 52.52, "longitude": 13.41 }
    readonly property var worldClocks: store.worldClocks ?? []
    readonly property var weatherLocation: store.weatherLocation ?? ({})

    // Aufbau des Datumsmenüs [GNOME-Mockup calendar-popover]
    //   calendarLayout:            "auto" (zweispaltig, sobald Termine sichtbar sind), "single" oder "split"
    //   calendarShowDateHeader:    Wochentag und Datum über den Terminen (zweispaltig)
    //   calendarShowEvents/…Clocks/…Weather: Abschnitte ein- und ausblenden
    //   calendarWeatherStyle:      "summary" (Zustand, Höchst-/Tiefstwert) oder "forecast" (stündlich)
    //   calendarUpcomingOnly:      nur noch anstehende Termine des heutigen Tages
    //   calendarAnalogClocks:      Weltuhren mit Zifferblatt
    //   calendarCompactClocksAbove / calendarPageClocksAbove: ab so vielen Uhren kompakte Liste bzw. Seiten
    //   weatherUnit:               "celsius" oder "fahrenheit"
    readonly property string calendarLayout: store.calendarLayout
    readonly property bool calendarShowDateHeader: store.calendarShowDateHeader
    readonly property bool calendarShowEvents: store.calendarShowEvents
    readonly property bool calendarShowWorldClocks: store.calendarShowWorldClocks
    readonly property bool calendarShowWeather: store.calendarShowWeather
    readonly property string calendarWeatherStyle: store.calendarWeatherStyle
    readonly property bool calendarUpcomingOnly: store.calendarUpcomingOnly
    readonly property bool calendarAnalogClocks: store.calendarAnalogClocks
    readonly property int calendarCompactClocksAbove: store.calendarCompactClocksAbove
    readonly property int calendarPageClocksAbove: store.calendarPageClocksAbove
    readonly property string weatherUnit: store.weatherUnit

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
            "id": "vitals",
            "title": "Vitals",
            "icon": "utilities-system-monitor-symbolic"
        },
        {
            "id": "updates",
            "title": "Updates",
            "icon": "software-update-available-symbolic"
        },
        {
            "id": "media",
            "title": "Media Player",
            "icon": "multimedia-player-symbolic"
        },
        {
            "id": "visualizer",
            "title": "Audio Visualizer",
            "icon": "audio-volume-high-symbolic"
        },
        {
            "id": "clock",
            "title": "Clock",
            "icon": "preferences-system-time-symbolic"
        },
        {
            "id": "capture",
            "title": "Recording",
            "icon": "media-record-symbolic"
        },
        {
            "id": "accessibility",
            "title": "Accessibility",
            "icon": "preferences-desktop-accessibility-symbolic"
        },
        {
            "id": "keyboard",
            "title": "Keyboard Layout",
            "icon": "input-keyboard-symbolic"
        },
        {
            "id": "status",
            "title": "System Menu",
            "icon": "emblem-system-symbolic",
            "required": true
        }
    ]
    readonly property var defaultBarLayout: ({
            "left": ["workspaces", "activeWindow"],
            "center": ["clock"],
            "right": ["capture", "updates", "keyboard", "status"]
        })
    readonly property var barLayout: _normalizeBarLayout(store.barLayout)

    function _normalizeBarLayout(raw) {
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
        store.barLayout = next;
    }
    function resetBarLayout() {
        store.barLayout = ({});
    }

    // Kacheln der Quick-Settings in Anzeigereihenfolge (IDs aus QuickSettings.tileCatalog); nicht gelistete Kacheln sind ausgeblendet
    // Das frühere "wifi" ist in "network" aufgegangen; alte Listen werden beim Laden umgeschrieben
    readonly property var quickToggles: _normalizeQuickToggles(store.quickToggles ?? defaultQuickToggles)
    readonly property var defaultQuickToggles: ["network", "bluetooth", "profile", "performance", "gamemode", "nightLight", "dark", "airplane", "dnd", "caffeine", "keyboard", "bigyahoo"]

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
    // wallpaperDark, wallpaperHistory, nightLightTemperature, quickToggles, defaultApps, worldClocks, weatherLocation, calendar*, weatherUnit)
    readonly property var keys: ["darkMode", "nightLight", "nightLightSchedule", "nightLightFrom", "nightLightTo", "doNotDisturb", "gameMode", "bigYahoo", "nightLightTemperature", "quickToggles", "useMatugen", "matugenScheme", "fontFamily", "fontFamilyMono", "clock12h", "showBatteryPercentage", "transparentBar", "barLayout", "barClockFormat", "barWorkspaceStyle", "barVisualizerBars", "barVitalsCpu", "barVitalsMemory", "barVitalsTemp", "barVitalsNet", "updatesAutoCheck", "updatesCheckHours", "barAppShowIcon", "barAppShowName", "barShowNetwork", "barShowBluetooth", "barShowVolume", "showPrivacyIndicators", "showStatusIndicators", "a11yLargeText", "a11yReduceMotion", "a11yScreenReader", "overviewLiveWindows", "dockIconSize", "dockPersistent", "dockAutohide", "showWeekNumbers", "weekStart", "wallpaper", "wallpaperDark", "wallpaperHistory", "defaultApps", "worldClocks", "weatherLocation", "calendarLayout", "calendarShowDateHeader", "calendarShowEvents", "calendarShowWorldClocks", "calendarShowWeather", "calendarWeatherStyle", "calendarUpcomingOnly", "calendarAnalogClocks", "calendarCompactClocksAbove", "calendarPageClocksAbove", "weatherUnit", "lockClockStyle", "lockClockSize", "lockClockWeight", "lockClockPosition", "lockClockColor", "lockDateFormat", "lockDateUppercase", "lockShowHint", "lockBlurCurtain", "shellBlur", "compact", "idleLockEnabled", "idleLockDelay", "idleSuspendEnabled", "idleSuspendDelay", "lockBeforeSuspend", "searchDisabled", "clipboardHistory", "primaryDisplay", "displays"]

    function set(key, value) {
        if (root.keys.indexOf(key) < 0)
            return false;
        if (key === "darkMode")
            root.darkMode = value;
        else if (key === "nightLight")
            root.nightLight = value;
        else if (key === "doNotDisturb")
            root.doNotDisturb = value;
        else if (key === "gameMode")
            root.gameMode = value;
        else if (key === "bigYahoo")
            root.bigYahoo = value;
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
            return root.keys.indexOf(key) < 0 ? "unknown key: " + key : JSON.stringify(key === "darkMode" ? root.darkMode : key === "nightLight" ? root.nightLight : key === "doNotDisturb" ? root.doNotDisturb : key === "gameMode" ? root.gameMode : key === "bigYahoo" ? root.bigYahoo : store[key]);
        }
        function list(): string {
            return root.keys.join("\n");
        }
    }

    function setDarkMode(on) {
        root.darkMode = on;
    }
    function setNightLight(on) {
        root.nightLight = on;
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
    function toggleNightLight() {
        root.nightLight = !root.nightLight;
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
    property string _nightLightBackend: ""

    // ───────── Persistenz ─────────

    FileView {
        id: file
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root._loaded = true;
            root.darkMode = store.darkMode;
            root.nightLight = store.nightLight;
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
            property bool nightLight: false
            property bool airplaneMode: false
            property bool doNotDisturb: false
            property bool gameMode: false
            property bool bigYahoo: false
            property int nightLightTemperature: 2700
            property string nightLightSchedule: "automatic"
            property real nightLightFrom: 20.0
            property real nightLightTo: 6.0
            property string primaryDisplay: ""
            property var displays: ({})
            property var quickToggles: ["network", "bluetooth", "profile", "performance", "gamemode", "nightLight", "dark", "airplane", "dnd", "caffeine", "keyboard", "bigyahoo"]
            property bool useMatugen: true
            property string matugenScheme: "scheme-tonal-spot"
            property string fontFamily: ""
            property string fontFamilyMono: ""
            property bool clock12h: false
            property bool showBatteryPercentage: false
            property var barLayout: ({})
            property string barClockFormat: "dateTime"
            property string barWorkspaceStyle: "dots"
            property bool updatesAutoCheck: true
            property int updatesCheckHours: 3
            property bool barVitalsCpu: true
            property bool barVitalsMemory: true
            property bool barVitalsTemp: true
            property bool barVitalsNet: false
            property int barVisualizerBars: 12
            property bool barAppShowIcon: true
            property bool barAppShowName: true
            property bool barShowNetwork: true
            property bool barShowBluetooth: true
            property bool barShowVolume: true
            property bool transparentBar: true
            property bool showPrivacyIndicators: true
            property bool showStatusIndicators: true
            property bool a11yLargeText: false
            property bool a11yReduceMotion: false
            property bool a11yScreenReader: false
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
            property var worldClocks: []
            property var weatherLocation: ({})
            property string calendarLayout: "auto"
            property bool calendarShowDateHeader: true
            property bool calendarShowEvents: true
            property bool calendarShowWorldClocks: true
            property bool calendarShowWeather: true
            property string calendarWeatherStyle: "summary"
            property bool calendarUpcomingOnly: true
            property bool calendarAnalogClocks: true
            property int calendarCompactClocksAbove: 4
            property int calendarPageClocksAbove: 6
            property string weatherUnit: "celsius"
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
    onNightLightChanged: store.nightLight = nightLight
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

    // ───────── Nachtlicht ─────────
    // hyprsunset/wlsunset halten die Farbtemperatur, solange der Prozess läuft; Beenden stellt sie zurück.
    // Zeitplan wie in GNOME (Displays › Nachtlicht): „automatic“ (Sonnenunter- bis -aufgang) oder „manual“.
    // Ohne Standortdaten dienen die gespeicherten Zeiten als Fenster; die Temperatur gilt, solange es aktiv ist.

    property int _nightTick: 0

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root._nightTick++
    }

    readonly property real _nowHours: {
        void root._nightTick;
        const d = new Date();
        return d.getHours() + d.getMinutes() / 60;
    }

    function _inWindow(h, from, to) {
        if (from === to)
            return true;
        return from < to ? (h >= from && h < to) : (h >= from || h < to);
    }

    // Sonnenuntergang/-aufgang als lokale Stunde (NOAA-Näherung) am Wetterort; null bei Polartag/-nacht
    function _sunTimes(date, lat, lon) {
        const rad = Math.PI / 180;
        const start = new Date(date.getFullYear(), 0, 0);
        const day = Math.floor((date - start) / 86400000);
        const g = 2 * Math.PI / 365 * (day - 1);
        const eqTime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        const cosH = Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl)) - Math.tan(lat * rad) * Math.tan(decl);
        if (cosH > 1 || cosH < -1)
            return { "polar": cosH > 1 ? "night" : "day" };
        const ha = Math.acos(cosH) / rad;
        const tz = -date.getTimezoneOffset() / 60;
        const noon = 12 - lon / 15 - eqTime / 60 + tz;
        return { "rise": noon - ha / 15, "set": noon + ha / 15 };
    }

    // Beginn/Ende der Nachtlicht-Zeit als Stundenbruch, je nach Zeitplan
    readonly property var _nightWindow: {
        void root._nightTick;
        if (root.nightLightSchedule === "manual")
            return { "from": root.nightLightFrom, "to": root.nightLightTo };
        const loc = root.weatherLocation;
        const lat = loc && loc.latitude !== undefined ? loc.latitude : 52.52;
        const lon = loc && loc.longitude !== undefined ? loc.longitude : 13.41;
        const t = root._sunTimes(new Date(), lat, lon);
        if (t.polar)
            return t.polar === "night" ? { "from": 0, "to": 0 } : { "from": 12, "to": 12.0001 };
        const wrap = h => ((h % 24) + 24) % 24;
        return { "from": wrap(t.set), "to": wrap(t.rise) };
    }

    // Nachtlicht ist eingeschaltet und (laut Zeitplan) gerade aktiv
    readonly property bool nightLightActive: {
        if (!root.nightLight || !root.nightLightAvailable)
            return false;
        return root._inWindow(root._nowHours, root._nightWindow.from, root._nightWindow.to);
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null && echo hyprsunset || { command -v wlsunset >/dev/null && echo wlsunset; }; true"]
        stdout: StdioCollector {
            onStreamFinished: root._nightLightBackend = text.trim()
        }
    }

    Process {
        running: root.nightLightActive
        command: root._nightLightBackend === "hyprsunset" ? ["hyprsunset", "--temperature", String(root.nightLightTemperature)] : ["wlsunset", "-t", String(root.nightLightTemperature), "-T", String(root.nightLightTemperature + 1), "-S", "23:59", "-s", "00:00", "-d", "1"]
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
