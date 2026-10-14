pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    property bool available: false


    readonly property var notifications: server.trackedNotifications.values.slice().reverse()
    readonly property int count: notifications.length
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

    function timeOf(n) {
        return n ? (root._times[n.id] ?? null) : null;
    }
    property var _times: ({})

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

    function groupKey(n) {
        return n.desktopEntry || n.appName;
    }


    property bool doNotDisturb: SettingsService.doNotDisturb
    onDoNotDisturbChanged: SettingsService.setDoNotDisturb(doNotDisturb)

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
    }


    property var banner: null
    property string bannerScreen: ""
    property bool bannerPaused: false
    property var _queue: []
    readonly property int queueCount: _queue.length
    property int _bannerInterval: Theme.notificationTimeout

    signal received(var notification)

    function hideBanner() {
        const n = root.banner;
        if (!n)
            return;
        root.banner = null;
        if (n.transient)
            n.expire();
        gap.restart();
    }

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

    function _enqueue(n) {
        if (n.urgency === NotificationUrgency.Low || root._queue.includes(n))
            return;
        const full = root._queue.length + (root.banner ? 1 : 0) >= Theme.notificationMaxQueue;
        if (full && n.urgency !== NotificationUrgency.Critical)
            return;
        const queue = root._queue.concat([n]);
        root._queue = queue.filter(q => q.urgency === NotificationUrgency.Critical).concat(queue.filter(q => q.urgency === NotificationUrgency.Normal), queue.filter(q => q.urgency === NotificationUrgency.Low));
        root._showNext();
    }

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
    function invoke(action) {
        if (action)
            action.invoke();
    }
    function activateDefault(n) {
        const a = n ? n.actions.find(a => a.identifier === "default") : null;
        if (a)
            a.invoke();
        return a !== undefined && a !== null;
    }
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

    Timer {
        id: gap
        interval: Theme.notificationHideTimeout
        onTriggered: root._showNext()
    }

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
