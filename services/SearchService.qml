pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "calc.js" as Calc

Singleton {
    id: root

    property string text: ""
    readonly property var terms: root.text.trim() === "" ? [] : root.text.trim().split(/\s+/)
    readonly property bool active: root.terms.length > 0

    property var apps: []
    property var settings: []
    property var files: []
    property var calculator: []
    property var commands: []
    property var windows: []
    property var actions: []
    property var clipboard: []
    property int filesMore: 0
    property int settingsMore: 0

    readonly property bool filesPending: filesTimer.running || filesQuery.running
    readonly property bool inProgress: root.filesPending

    readonly property var allProviders: [
        {
            "id": "apps",
            "name": "Apps",
            "description": "Installed applications",
            "icon": "view-app-grid-symbolic",
            "grid": true
        },
        {
            "id": "windows",
            "name": "Fenster",
            "description": "Switch to an open window",
            "icon": root._icon(["focus-windows-symbolic", "window-new-symbolic"], "window-new-symbolic"),
            "grid": false
        },
        {
            "id": "actions",
            "name": "System",
            "description": "Lock, suspend, power off, caffeine and quick toggles",
            "icon": root._icon(["system-shutdown-symbolic", "emblem-system-symbolic"], "emblem-system-symbolic"),
            "grid": false
        },
        {
            "id": "settings",
            "name": "Einstellungen",
            "description": "Settings panels",
            "icon": root._icon(["preferences-system-symbolic"], "emblem-system-symbolic"),
            "grid": false
        },
        {
            "id": "files",
            "name": "Dateien",
            "description": "Files and folders (needs localsearch)",
            "icon": root._icon(["system-file-manager-symbolic", "folder-symbolic"], "folder-symbolic"),
            "grid": false,
            "actionLabel": "In Dateien suchen"
        },
        {
            "id": "calculator",
            "name": "Rechner",
            "description": "Calculations and unit-free maths",
            "icon": root._icon(["accessories-calculator-symbolic"], "accessories-calculator-symbolic"),
            "grid": false
        },
        {
            "id": "clipboard",
            "name": "Zwischenablage",
            "description": "Clipboard history — start the search with “clip” or “cb”",
            "icon": root._icon(["edit-paste-symbolic"], "edit-paste-symbolic"),
            "grid": false
        },
        {
            "id": "commands",
            "name": "Befehle",
            "description": "Run a program or shell command (prefix > or !)",
            "icon": root._icon(["utilities-terminal-symbolic"], "utilities-terminal-symbolic"),
            "grid": false
        }
    ]

    function enabled(providerId) {
        return SettingsService.searchDisabled.indexOf(providerId) < 0;
    }
    function setEnabled(providerId, on) {
        const rest = SettingsService.searchDisabled.filter(i => i !== providerId);
        SettingsService.set("searchDisabled", on ? rest : rest.concat([providerId]));
    }
    readonly property var providers: root.allProviders.filter(p => root.enabled(p.id))

    function _providerIcon(id) {
        return root.allProviders.find(p => p.id === id)?.icon ?? "";
    }

    function results(providerId) {
        return root[providerId] ?? [];
    }

    function moreCount(providerId) {
        if (providerId === "files")
            return root.filesMore;
        if (providerId === "settings")
            return root.settingsMore;
        return 0;
    }

    readonly property var defaultResult: {
        for (const p of root.providers) {
            const list = root.results(p.id);
            if (list.length > 0)
                return {
                    "provider": p.id,
                    "result": list[0]
                };
        }
        return null;
    }
    readonly property bool hasResults: root.defaultResult !== null

    function _icon(names, fallback) {
        for (const n of names) {
            if (Quickshell.iconPath(n, true) !== "")
                return n;
        }
        return fallback;
    }


    function reset() {
        root.text = "";
    }

    onTextChanged: root._update()

    readonly property var settingsIndex: AppsService.makeIndex(SettingsPanelsService.searchable)

    function _panelResult(panel) {
        return {
            "id": panel.id,
            "name": panel.name,
            "description": panel.description ?? "",
            "icon": panel.icon,
            "panel": panel.panel
        };
    }

    function _entryResult(entry) {
        return {
            "id": entry.id,
            "name": entry.name,
            "description": entry.comment || entry.genericName || "",
            "icon": entry.icon || "application-x-executable",
            "entry": entry
        };
    }

    function _update() {
        const q = root.text.trim();
        if (q === "") {
            root.apps = [];
            root.settings = [];
            root.files = [];
            root.filesMore = 0;
            root.calculator = [];
            root.commands = [];
            root.windows = [];
            root.actions = [];
            root.clipboard = [];
            filesTimer.stop();
            filesQuery.running = false;
            return;
        }
        root.apps = AppsService.search(q).slice(0, Theme.searchAppsMaxResults).map(e => root._entryResult(e));
        const set = AppsService.searchIndex(root.settingsIndex, q);
        root.settings = set.slice(0, Theme.searchListMaxRows).map(e => root._panelResult(e));
        root.settingsMore = Math.max(0, set.length - Theme.searchListMaxRows);
        root._updateCalculator(q);
        root._updateCommands(q);
        root._updateWindows(q);
        root._updateActions(q);
        root._updateClipboard(q);
        if (root.enabled("files"))
            filesTimer.restart();
        else
            root.files = [];
    }


    function _updateWindows(q) {
        if (!root.enabled("windows")) {
            root.windows = [];
            return;
        }
        const terms = q.toLowerCase().split(/\s+/).filter(t => t !== "");
        const out = [];
        for (const t of WorkspaceService.windows) {
            const ipc = t.lastIpcObject ?? {};
            const cls = ipc.class ?? "";
            const title = ipc.title ?? t.title ?? "";
            if (cls === "")
                continue;
            const hay = (title + " " + cls).toLowerCase();
            if (!terms.every(w => hay.indexOf(w) >= 0))
                continue;
            const entry = AppsService.entryForWindow(t);
            out.push({
                "id": "window:" + t.address,
                "name": title !== "" ? title : (entry ? entry.name : cls),
                "description": (entry ? entry.name : cls) + (ipc.workspace?.name ? " · Workspace " + ipc.workspace.name : ""),
                "icon": entry && entry.icon ? entry.icon : "application-x-executable",
                "symbolic": false,
                "window": t
            });
        }
        root.windows = out.slice(0, Theme.searchListMaxRows);
    }


    readonly property var actionList: {
        const l = [];
        l.push({
            "id": "lock",
            "name": "Lock Screen",
            "keywords": "lock screen secure sperren bildschirm"
        });
        if (SessionService.canSuspend)
            l.push({
                "id": "suspend",
                "name": "Suspend",
                "keywords": "sleep standby suspend ruhezustand schlafen"
            });
        if (SessionService.canLogout)
            l.push({
                "id": "logout",
                "name": "Log Out",
                "keywords": "log out logout sign out abmelden"
            });
        if (SessionService.canReboot)
            l.push({
                "id": "reboot",
                "name": "Restart",
                "keywords": "restart reboot neustart"
            });
        if (SessionService.canPowerOff)
            l.push({
                "id": "poweroff",
                "name": "Power Off",
                "keywords": "power off shut down shutdown herunterfahren ausschalten"
            });
        l.push({
            "id": "caffeine",
            "name": IdleService.caffeine ? "Turn Caffeine Off" : "Turn Caffeine On",
            "keywords": "caffeine keep awake inhibit idle sleep lock koffein"
        });
        l.push({
            "id": "dnd",
            "name": SettingsService.doNotDisturb ? "Turn Do Not Disturb Off" : "Turn Do Not Disturb On",
            "keywords": "do not disturb dnd notifications nicht stören"
        });
        l.push({
            "id": "dark",
            "name": SettingsService.darkMode ? "Switch to Light Style" : "Switch to Dark Style",
            "keywords": "dark light style theme mode dunkel hell"
        });
        l.push({
            "id": "screenshot",
            "name": "Take a Screenshot",
            "keywords": "screenshot screen capture record bildschirmfoto"
        });
        return l;
    }
    readonly property var _actionIcons: ({
            "lock": "system-lock-screen-symbolic",
            "suspend": "weather-clear-night-symbolic",
            "logout": "system-log-out-symbolic",
            "reboot": "system-reboot-symbolic",
            "poweroff": "system-shutdown-symbolic",
            "caffeine": Quickshell.shellPath("assets/icons/caffeine-symbolic.svg"),
            "dnd": "notifications-disabled-symbolic",
            "dark": Quickshell.shellPath("assets/icons/dark-mode-symbolic.svg"),
            "screenshot": "applets-screenshooter-symbolic"
        })
    readonly property var actionIndex: AppsService.makeIndex(root.actionList.map(a => ({
                "id": a.id,
                "name": a.name,
                "genericName": "",
                "keywords": a.keywords,
                "comment": "",
                "icon": root._actionIcons[a.id] ?? "emblem-system-symbolic",
                "action": a.id
            })))

    function _updateActions(q) {
        if (!root.enabled("actions")) {
            root.actions = [];
            return;
        }
        root.actions = AppsService.searchIndex(root.actionIndex, q).slice(0, Theme.searchListMaxRows).map(e => ({
                    "id": "action:" + e.id,
                    "name": e.name,
                    "description": "",
                    "icon": e.icon,
                    "action": e.action
                }));
    }

    function _runAction(id) {
        switch (id) {
        case "lock":
            SessionService.lock();
            break;
        case "suspend":
            SessionService.suspend();
            break;
        case "logout":
            SessionService.logout();
            break;
        case "reboot":
            SessionService.reboot();
            break;
        case "poweroff":
            SessionService.powerOff();
            break;
        case "caffeine":
            IdleService.toggleCaffeine();
            break;
        case "dnd":
            SettingsService.toggleDoNotDisturb();
            break;
        case "dark":
            SettingsService.toggleDarkMode();
            break;
        case "screenshot":
            SessionService.screenshot();
            break;
        }
    }


    function _updateClipboard(q) {
        const m = /^(clip|cb|clipboard)(?:\s+(.*))?$/i.exec(q);
        if (!m || !root.enabled("clipboard") || !ClipboardService.enabled) {
            root.clipboard = [];
            return;
        }
        ClipboardService.refresh();
        root._clipTerms = (m[2] ?? "").toLowerCase().split(/\s+/).filter(t => t !== "");
        root._filterClipboard();
    }

    property var _clipTerms: []
    function _filterClipboard() {
        const terms = root._clipTerms;
        const out = [];
        for (const e of ClipboardService.entries) {
            const lower = e.text.toLowerCase();
            if (!terms.every(w => lower.indexOf(w) >= 0))
                continue;
            out.push({
                "id": "clip:" + e.id,
                "name": e.label,
                "description": e.meta,
                "icon": e.icon,
                "clip": e
            });
            if (out.length >= Theme.searchListMaxRows)
                break;
        }
        root.clipboard = out;
    }
    Connections {
        target: ClipboardService
        function onEntriesChanged() {
            if (root.clipboard.length > 0 || /^(clip|cb|clipboard)(\s|$)/i.test(root.text.trim()))
                root._filterClipboard();
        }
    }

    function _updateCalculator(q) {
        const value = Calc.evaluate(q.replace(/=+$/, ""));
        if (value === null) {
            root.calculator = [];
            return;
        }
        const result = Calc.format(value, Qt.locale().decimalPoint);
        root.calculator = [
            {
                "id": "calculator",
                "name": result,
                "description": q.replace(/=+$/, "").trim() + " =",
                "icon": root._providerIcon("calculator"),
                "copy": result
            }
        ];
    }

    property var executables: ({})
    property bool executablesLoaded: false

    function _updateCommands(q) {
        const forced = /^[>!]/.test(q);
        const cmd = forced ? q.slice(1).trim() : q;
        if (cmd === "") {
            root.commands = [];
            return;
        }
        if (!root.executablesLoaded && !pathScan.running) {
            pathScan.running = true;
        }
        const program = cmd.split(/\s+/)[0];
        const isProgram = !!root.executables[program];
        if (!forced && !isProgram) {
            root.commands = [];
            return;
        }
        if (!forced && cmd === program && root.apps.some(r => r.entry && (r.entry.command ?? [])[0]?.split("/").pop() === program)) {
            root.commands = [];
            return;
        }
        root.commands = [
            {
                "id": "command:" + cmd,
                "name": cmd,
                "description": "Befehl ausführen",
                "icon": root._providerIcon("commands"),
                "command": cmd
            }
        ];
    }

    Process {
        id: pathScan
        command: ["sh", "-c", 'IFS=:; for d in $PATH; do [ -d "$d" ] && ls -1 "$d" 2>/dev/null; done | sort -u']
        stdout: StdioCollector {
            onStreamFinished: {
                const set = {};
                for (const line of text.split("\n")) {
                    if (line !== "")
                        set[line] = true;
                }
                root.executables = set;
                root.executablesLoaded = true;
                root._updateCommands(root.text.trim());
            }
        }
    }


    Timer {
        id: filesTimer
        interval: Theme.searchDelay
        onTriggered: root._searchFiles()
    }

    function _sparqlString(s) {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\u0000-\u001f]/g, " ") + '"';
    }

    function _searchFiles() {
        const terms = root.terms.map(t => t.toLowerCase()).filter(t => t !== "");
        if (terms.length === 0) {
            root.files = [];
            root.filesMore = 0;
            return;
        }
        const nameFilter = terms.map(t => "CONTAINS(LCASE(?name), " + root._sparqlString(t) + ")").join(" && ");
        const query = "SELECT DISTINCT ?url ?mime ?name WHERE { ?f a nfo:FileDataObject ; nie:url ?url ; nfo:fileName ?name . FILTER (" + nameFilter + ") OPTIONAL { ?ie nie:isStoredAs ?f ; nie:mimeType ?mime } OPTIONAL { ?f nfo:fileLastModified ?mod } } ORDER BY DESC(?mod) LIMIT " + Theme.searchFilesQueryLimit;
        filesQuery.running = false;
        filesQuery.pendingTerms = root.text;
        filesQuery.command = ["tinysparql", "query", "-b", "org.freedesktop.Tracker3.Miner.Files", "-q", query];
        filesQuery.running = true;
    }

    function mimeIcon(mime) {
        if (!mime)
            return "text-x-generic";
        const specific = mime.replace("/", "-");
        if (Quickshell.iconPath(specific, true) !== "")
            return specific;
        const generic = mime.split("/")[0] + "-x-generic";
        if (Quickshell.iconPath(generic, true) !== "")
            return generic;
        return "text-x-generic";
    }

    function _homeShort(path) {
        const home = Quickshell.env("HOME") ?? "";
        return home !== "" && path.startsWith(home) ? "~" + path.slice(home.length) : path;
    }

    function _parseFileLine(line) {
        const m = /^\s*(file:\/\/.*?), ([\w.+-]+\/[\w.+-]+)?, (.*)$/.exec(line);
        if (!m)
            return null;
        let path = "";
        try {
            path = decodeURIComponent(m[1].replace(/^file:\/\//, ""));
        } catch (e) {
            return null;
        }
        const dir = path.slice(0, path.lastIndexOf("/"));
        return {
            "id": m[1],
            "name": m[3],
            "description": root._homeShort(dir === "" ? "/" : dir),
            "icon": root.mimeIcon(m[2]),
            "url": m[1]
        };
    }

    Process {
        id: filesQuery

        property string pendingTerms: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (filesQuery.pendingTerms !== root.text)
                    return;
                const all = [];
                for (const line of text.split("\n")) {
                    const r = root._parseFileLine(line);
                    if (r)
                        all.push(r);
                }
                const first = root.terms[0]?.toLowerCase() ?? "";
                const starts = all.filter(r => r.name.toLowerCase().startsWith(first));
                const rest = all.filter(r => !r.name.toLowerCase().startsWith(first));
                const ordered = starts.concat(rest);
                root.files = ordered.slice(0, Theme.searchListMaxRows);
                root.filesMore = Math.max(0, ordered.length - Theme.searchListMaxRows);
            }
        }
    }


    function activate(providerId, result) {
        if (!result)
            return false;
        switch (providerId) {
        case "apps":
            AppsService.launch(result.entry);
            return true;
        case "settings":
            SettingsWindowService.show(result.panel);
            return true;
        case "files":
            Quickshell.execDetached(["xdg-open", result.url]);
            return true;
        case "calculator":
            Quickshell.execDetached(["wl-copy", result.copy]);
            return true;
        case "commands":
            Quickshell.execDetached(["sh", "-c", result.command]);
            return true;
        case "windows":
            WorkspaceService.focusWindow(result.window);
            return true;
        case "actions":
            root._runAction(result.action);
            return true;
        case "clipboard":
            ClipboardService.copy(result.clip);
            return true;
        }
        return false;
    }

    function providerAction(providerId) {
        if (providerId !== "files")
            return false;
        Quickshell.execDetached(["sh", "-c", 'nautilus --search "$1" || xdg-open "$HOME"', "sh", root.text.trim()]);
        return true;
    }

    function highlight(text) {
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        if (!text)
            return "";
        const words = root.terms.filter(t => t !== "").map(t => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
        if (words.length === 0)
            return esc(text);
        const re = new RegExp(words.join("|"), "gi");
        let out = "";
        let last = 0;
        let m;
        while ((m = re.exec(text)) !== null) {
            if (m[0].length === 0) {
                re.lastIndex++;
                continue;
            }
            out += esc(text.slice(last, m.index)) + "<b>" + esc(m[0]) + "</b>";
            last = m.index + m[0].length;
        }
        return out + esc(text.slice(last));
    }
}
