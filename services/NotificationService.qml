pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// Benachrichtigungs-Server (org.freedesktop.Notifications) mit Gruppen nach App, Banner-Warteschlange und
// Nicht stören. Verhalten nach messageTray.js: Banner 4 s (niedrige Dringlichkeit ohne Banner), kritische bleiben stehen und umgehen DND,
// alle Meldungen bleiben in der Liste, bis sie verworfen werden (transiente verschwinden mit dem Banner).
Singleton {
    id: root

    // Der Server besitzt den Busnamen. false, wenn ein anderer Daemon (mako, dunst, …) ihn hält.
    property bool available: false

    // ───────── Liste und Gruppen ─────────

    // Alle gespeicherten Meldungen, neueste zuerst (ersetzende Meldungen aktualisieren dasselbe Objekt)
    readonly property var notifications: server.trackedNotifications.values.slice().reverse()
    readonly property int count: notifications.length
    // [{ key, appName, appIcon, desktopEntry, notifications: [...], count }], Gruppe mit neuester Meldung zuerst
    readonly property var groups: {
        const byKey = {};
        const list = [];
        for (const n of notifications) {
            const key = root.groupKey(n);
            let g = byKey[key];
            if (!g) {
                g = {
                    key,
                    appName: n.appName,
                    appIcon: n.appIcon,
                    desktopEntry: n.desktopEntry,
                    notifications: [],
                    count: 0
                };
                byKey[key] = g;
                list.push(g);
            }
            g.notifications.push(n);
            g.count++;
        }
        return list;
    }

    // Empfangszeit je Meldung (Date); Quickshell liefert keinen Zeitstempel, daher beim Eintreffen gemerkt
    function timeOf(n) {
        return n ? (root._times[n.id] ?? null) : null;
    }
    property var _times: ({})

    // "Gerade eben", "Vor 5 Minuten", … [dateUtils.js formatTimeSpan]
    function timeSpan(date, now) {
        if (!date)
            return "";
        const de = Qt.locale().name.startsWith("de");
        const n = now ?? new Date();
        const minutes = (n - date) / 60000;
        const hours = minutes / 60;
        const days = hours / 24;
        const weeks = days / 7;
        const months = days / 30;
        const years = weeks / 52;
        const plural = (v, one, many, oneEn, manyEn) => {
            const c = Math.floor(v);
            return de ? "Vor " + c + " " + (c === 1 ? one : many) : c + " " + (c === 1 ? oneEn : manyEn) + " ago";
        };
        if (minutes < 5)
            return de ? "Gerade eben" : "Just now";
        if (hours < 1)
            return plural(minutes, "Minute", "Minuten", "minute", "minutes");
        if (days < 1)
            return plural(hours, "Stunde", "Stunden", "hour", "hours");
        if (days < 2)
            return de ? "Gestern" : "Yesterday";
        if (days < 15)
            return plural(days, "Tag", "Tagen", "day", "days");
        if (weeks < 8)
            return plural(weeks, "Woche", "Wochen", "week", "weeks");
        if (years < 1)
            return plural(months, "Monat", "Monaten", "month", "months");
        return plural(years, "Jahr", "Jahren", "year", "years");
    }

    // Schlüssel, nach dem Meldungen gruppiert werden
    function groupKey(n) {
        return n.desktopEntry || n.appName;
    }

    // ───────── Nicht stören ─────────

    // Gespiegelt aus SettingsService (doNotDisturb)
    property bool doNotDisturb: SettingsService.doNotDisturb
    onDoNotDisturbChanged: SettingsService.setDoNotDisturb(doNotDisturb)

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
    }

    // ───────── Banner ─────────

    // Aktuell angezeigter Banner (Notification) oder null
    property var banner: null
    // Monitor, auf dem der Banner erscheint (Name des fokussierten Monitors beim Einblenden)
    property string bannerScreen: ""
    // Zeigt die UI den Banner unter dem Mauszeiger, läuft der Timeout nicht
    property bool bannerPaused: false
    property var _queue: []
    readonly property int queueCount: _queue.length
    // Dauer bis zum Ausblenden, wenn der Timer das nächste Mal startet
    property int _bannerInterval: Theme.notificationTimeout

    // Neue Meldung (vor dem Einreihen als Banner)
    signal received(var notification)

    function hideBanner() {
        const n = root.banner;
        if (!n)
            return;
        root.banner = null;
        // Transiente Meldungen erscheinen nur als Banner und nicht in der Liste
        if (n.transient)
            n.expire();
        gap.restart();
    }

    // Der Zeiger betritt/verlässt den Banner: darunter steht der Timer still, nach dem Verlassen
    // blendet er nach LONGER_HIDE_TIMEOUT aus [messageTray.js:977-1035]
    function setBannerHovered(hovered) {
        if (!hovered)
            root._bannerInterval = Theme.notificationLeaveTimeout;
        root.bannerPaused = hovered;
    }

    function _showNext() {
        if (root.banner !== null || root._queue.length === 0)
            return;
        root.bannerScreen = WorkspaceService.focusedMonitor?.name ?? "";
        root._bannerInterval = Theme.notificationTimeout;
        root.bannerPaused = false;
        root.banner = root._queue[0];
        root._queue = root._queue.slice(1);
    }

    // Banner anfordern [messageTray.js:930-967]: niedrige Dringlichkeit nie, bei voller Warteschlange nur kritische;
    // höhere Dringlichkeit zuerst
    function _enqueue(n) {
        if (n.urgency === NotificationUrgency.Low || root._queue.includes(n))
            return;
        const full = root._queue.length + (root.banner ? 1 : 0) >= Theme.notificationMaxQueue;
        if (full && n.urgency !== NotificationUrgency.Critical)
            return;
        // Höhere Dringlichkeit zuerst, gleiche in Eingangsreihenfolge (sort() ist nicht stabil)
        const queue = root._queue.concat([n]);
        root._queue = queue.filter(q => q.urgency === NotificationUrgency.Critical).concat(queue.filter(q => q.urgency === NotificationUrgency.Normal), queue.filter(q => q.urgency === NotificationUrgency.Low));
        root._showNext();
    }

    // Wird der angezeigte Banner aktualisiert, beginnt die Anzeigedauer neu [messageTray.js:938-942]
    function _onUpdated(n) {
        if (root.banner === n) {
            root._bannerInterval = Theme.notificationTimeout;
            if (!root.bannerPaused && n.urgency !== NotificationUrgency.Critical)
                bannerTimer.restart();
        }
    }

    function _onClosed(n) {
        delete root._times[n.id];
        root._queue = root._queue.filter(q => q !== n);
        if (root.banner === n) {
            root.banner = null;
            gap.restart();
        }
    }

    // ───────── Aktionen ─────────

    function dismiss(n) {
        if (n)
            n.dismiss();
    }
    function dismissGroup(key) {
        for (const n of root.notifications.filter(n => root.groupKey(n) === key))
            n.dismiss();
    }
    function clearAll() {
        for (const n of root.notifications)
            n.dismiss();
    }
    // Aktion ausführen (schließt die Meldung, außer sie ist resident)
    function invoke(action) {
        if (action)
            action.invoke();
    }
    // Klick auf die Meldung selbst: Standardaktion, sonst nichts
    function activateDefault(n) {
        const a = n ? n.actions.find(a => a.identifier === "default") : null;
        if (a)
            a.invoke();
        return a !== undefined && a !== null;
    }
    // Klick auf den Banner: Standardaktion, die App in den Vordergrund, Meldung schließen (außer resident)
    function activate(n) {
        if (!n)
            return;
        const invoked = root.activateDefault(n);
        root.focusApp(n);
        if (!invoked && !n.resident)
            n.dismiss();
        if (root.banner === n)
            root.hideBanner();
    }
    // Fenster der sendenden App fokussieren (Zuordnung über desktop-entry, sonst App-Name)
    function focusApp(n) {
        const id = (n.desktopEntry || "").replace(/\.desktop$/, "").toLowerCase();
        const name = (n.appName || "").toLowerCase();
        const run = AppsService.runningApps.find(r => {
            const cls = r.appId.toLowerCase();
            return (id !== "" && (cls === id || (r.entry && r.entry.id.toLowerCase() === id))) || (name !== "" && cls === name);
        });
        if (run && run.windows.length > 0)
            WorkspaceService.focusWindow(run.windows[0]);
    }
    function reply(n, text) {
        if (n && n.hasInlineReply)
            n.sendInlineReply(text);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true

        onNotification: n => {
            root._times[n.id] = new Date();
            n.tracked = true;
            n.closed.connect(() => root._onClosed(n));
            n.summaryChanged.connect(() => root._onUpdated(n));
            n.bodyChanged.connect(() => root._onUpdated(n));
            root.received(n);
            // Kritische Meldungen umgehen Nicht stören [messageTray.js:938]
            if (!root.doNotDisturb || n.urgency === NotificationUrgency.Critical)
                root._enqueue(n);
        }
    }

    Timer {
        id: bannerTimer
        interval: root._bannerInterval
        running: root.banner !== null && root.banner.urgency !== NotificationUrgency.Critical && !root.bannerPaused
        onTriggered: root.hideBanner()
    }

    // Kurze Pause zwischen zwei Bannern [messageTray.js:21]
    Timer {
        id: gap
        interval: Theme.notificationHideTimeout
        onTriggered: root._showNext()
    }

    // Busnamen prüfen: gehört er einem anderen Prozess, ist der Server hier wirkungslos
    Process {
        id: owner
        command: ["busctl", "--user", "status", "org.freedesktop.Notifications"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/^PID=(\d+)/m);
                root.available = m !== null && parseInt(m[1]) === Quickshell.processId;
            }
        }
    }

    Timer {
        interval: 500
        running: true
        onTriggered: owner.running = true
    }
}
