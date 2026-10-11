pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Termine für Kalender und Terminliste im Datumsmenü [calendar.js EventSourceBase/DBusEventSource, dateMenu.js].
// Quelle:
//   "khal": `khal list --json …`, neu gelesen, wenn das Menü öffnet oder sich der sichtbare Monat ändert.
//   "":     khal fehlt; `available` bleibt false und der Terminbereich wird ausgeblendet.
// NISELLE_DATEMENU_DEMO=1 liefert feste Beispieltermine.
Singleton {
    id: root

    readonly property bool demo: Quickshell.env("NISELLE_DATEMENU_DEMO") === "1"

    // Es gibt mindestens einen Kalender (hasCalendars)
    readonly property bool available: demo || backend === "khal"
    readonly property bool loading: _loading
    // "khal" oder ""
    readonly property string backend: _backend

    // [{ id, summary, start: Date, end: Date, allDay }]
    readonly property var events: demo ? _demoEvents : _events

    // Sichtbaren Bereich setzen (Kalender: 6 Wochen). Holt die Termine, wenn sich der Bereich ändert oder `force`.
    function requestRange(begin, end, force) {
        if (!force && _rangeBegin && _rangeBegin.getTime() === begin.getTime() && _rangeEnd.getTime() === end.getTime())
            return;
        _rangeBegin = new Date(begin);
        _rangeEnd = new Date(end);
        _reload();
    }
    // Erneut lesen (Menü wird geöffnet)
    function refresh() {
        if (_rangeBegin)
            _reload();
    }

    // Termine, die [begin, end) berühren, nach Beginn sortiert [calendar.js DBusEventSource.getEvents]
    function getEvents(begin, end) {
        return events.filter(e => e.start < end && (e.end > begin || (e.start.getTime() === e.end.getTime() && e.start >= begin))).sort((a, b) => a.start - b.start || a.end - b.end);
    }
    function hasEvents(day) {
        const begin = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const end = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
        return getEvents(begin, end).length > 0;
    }

    property string _backend: ""
    property bool _loading: false
    property var _events: []
    property var _rangeBegin: null
    property var _rangeEnd: null

    function _reload() {
        if (_backend === "khal")
            _khalList();
    }

    // ───────── Erkennung ─────────

    Process {
        running: !root.demo
        command: ["sh", "-c", "command -v khal >/dev/null && echo khal; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._backend = text.trim();
                if (root._backend === "khal")
                    khalFormats.running = true;
            }
        }
    }

    // Ganztägig: beginnt und endet um Mitternacht
    function _isAllDay(start, end) {
        const midnight = d => d.getHours() === 0 && d.getMinutes() === 0 && d.getSeconds() === 0;
        return midnight(start) && midnight(end) && end > start;
    }

    // ───────── khal ─────────
    // Datumsformate hängen von der khal-Konfiguration ab: `khal printformats` zeigt sie am Beispiel 21.12.2013 10:09,
    // daraus werden Formatierer und Parser abgeleitet.

    property string _khalDateFormat: ""
    property string _khalDateTimeFormat: ""

    Process {
        id: khalFormats
        command: ["khal", "printformats"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\w+):\s?(.*)$/);
                    if (!m)
                        continue;
                    if (m[1] === "longdateformat")
                        root._khalDateFormat = m[2];
                    else if (m[1] === "longdatetimeformat")
                        root._khalDateTimeFormat = m[2];
                }
                // Nur numerische Formate lassen sich sicher zurücklesen
                if (!/2013/.test(root._khalDateFormat) || /[A-Za-z]{3,}/.test(root._khalDateTimeFormat.replace(/AM|PM/, "")))
                    root._backend = "";
                else
                    root._khalList();
            }
        }
    }

    function _pad(n) {
        return n < 10 ? "0" + n : String(n);
    }

    function _khalFormatDate(d) {
        return _khalDateFormat.replace(/2013|12|21/g, t => t === "2013" ? String(d.getFullYear()) : t === "12" ? _pad(d.getMonth() + 1) : _pad(d.getDate()));
    }

    // Beispiel "21.12.2013 10:09" → Regex mit Gruppen in der Reihenfolge des Formats
    function _khalParse(s) {
        const tokens = [["2013", "y"], ["21", "d"], ["12", "M"], ["10", "h"], ["09", "m"], ["AM", "p"]];
        let pattern = _khalDateTimeFormat.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const order = [];
        for (const [token, key] of tokens) {
            const i = pattern.indexOf(token);
            if (i < 0)
                continue;
            order.push([i, key]);
            pattern = pattern.slice(0, i) + (key === "p" ? "(AM|PM)" : key === "y" ? "(\\d{4})" : "(\\d{1,2})") + pattern.slice(i + token.length);
        }
        order.sort((a, b) => a[0] - b[0]);
        const m = s.trim().match(new RegExp("^" + pattern + "$"));
        if (!m)
            return null;
        const v = {};
        order.forEach((o, i) => v[o[1]] = m[i + 1]);
        let hour = parseInt(v.h ?? "0");
        if (v.p === "PM" && hour < 12)
            hour += 12;
        else if (v.p === "AM" && hour === 12)
            hour = 0;
        return new Date(parseInt(v.y), parseInt(v.M) - 1, parseInt(v.d), hour, parseInt(v.m ?? "0"));
    }

    function _khalList() {
        if (!_rangeBegin || _khalDateFormat === "" || khalList.running)
            return;
        _loading = true;
        khalList.command = ["khal", "list", "--once", "--day-format", "", "--json", "uid", "--json", "title", "--json", "start-long-full", "--json", "end-long-full", "--json", "all-day", _khalFormatDate(_rangeBegin), _khalFormatDate(_rangeEnd)];
        khalList.running = true;
    }

    Process {
        id: khalList
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line.startsWith("["))
                        continue;
                    let items;
                    try {
                        items = JSON.parse(line);
                    } catch (e) {
                        continue;
                    }
                    for (const it of items) {
                        const start = root._khalParse(it["start-long-full"]);
                        let end = root._khalParse(it["end-long-full"]);
                        if (!start || !end)
                            continue;
                        const allDay = String(it["all-day"]).toLowerCase() === "true";
                        // khal nennt bei ganztägigen Terminen den letzten Tag; GNOME rechnet mit exklusivem Ende
                        if (allDay)
                            end = new Date(end.getFullYear(), end.getMonth(), end.getDate() + 1);
                        list.push({
                            "id": it.uid + "@" + start.getTime(),
                            "summary": it.title,
                            "start": allDay ? new Date(start.getFullYear(), start.getMonth(), start.getDate()) : start,
                            "end": end,
                            "allDay": allDay
                        });
                    }
                }
                root._events = list;
            }
        }
        onExited: root._loading = false
    }

    // ───────── Beispieldaten ─────────

    readonly property var _demoEvents: {
        const now = new Date();
        const at = (dayOffset, h, m) => new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset, h, m);
        return [
            {
                "id": "demo-1",
                "summary": "Team-Besprechung",
                "start": at(0, 10, 0),
                "end": at(0, 11, 0),
                "allDay": false
            },
            {
                "id": "demo-2",
                "summary": "Zahnarzt",
                "start": at(0, 15, 30),
                "end": at(0, 16, 15),
                "allDay": false
            },
            {
                "id": "demo-3",
                "summary": "Geburtstag Anna",
                "start": at(1, 0, 0),
                "end": at(2, 0, 0),
                "allDay": true
            },
            {
                "id": "demo-4",
                "summary": "Konferenz",
                "start": at(5, 9, 0),
                "end": at(7, 17, 0),
                "allDay": false
            }
        ];
    }
}
