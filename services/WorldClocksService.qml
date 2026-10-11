pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Weltuhren für das Datumsmenü [dateMenu.js WorldClocksSection]. Orte kommen aus SettingsService.worldClocks
// ({ name, timezone }); gespeichert in SettingsService (worldClocks).
// UTC-Versatz je Zeitzone liefert `date` (beim Öffnen des Menüs neu, wegen Sommerzeit); die Uhrzeit rechnet die
// Shell aus der Systemuhr. Keine Orte → `available` false, Abschnitt ausgeblendet.
Singleton {
    id: root

    readonly property bool demo: Quickshell.env("NISELLE_DATEMENU_DEMO") === "1"
    readonly property var locations: demo ? [
        {
            "name": "San Francisco",
            "timezone": "America/Los_Angeles"
        },
        {
            "name": "Tokio",
            "timezone": "Asia/Tokyo"
        }
    ] : (SettingsService.worldClocks ?? []).filter(l => l && l.timezone)

    readonly property bool available: locations.length > 0

    // [{ name, timezone, offset }] nach Versatz sortiert, offset in Minuten (UTC)
    readonly property var clocks: _clocks
    // Lokaler UTC-Versatz in Minuten
    readonly property int localOffset: _localOffset

    property var _clocks: []
    property int _localOffset: 0

    // Uhrzeit am Ort als Date, dessen lokale Felder die Ortszeit zeigen
    function timeAt(clock, now) {
        return new Date(now.getTime() + (clock.offset - root._localOffset) * 60000);
    }

    // "+9", "-7", "+5:30" relativ zur lokalen Zeit [dateMenu.js _getTimezoneOffsetAtLocation]
    function relativeOffset(clock) {
        const diff = clock.offset - root._localOffset;
        const hours = Math.floor(Math.abs(diff) / 60);
        const minutes = Math.abs(diff) % 60;
        return (diff >= 0 ? "+" : "-") + hours + (minutes === 0 ? "" : ":" + minutes);
    }

    function refresh() {
        if (root.available && !offsets.running)
            offsets.running = true;
    }

    onLocationsChanged: refresh()

    function _minutes(z) {
        const m = z.match(/^([+-])(\d\d)(\d\d)$/);
        if (!m)
            return 0;
        return (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3]));
    }

    // Erste Zeile: lokaler Versatz, danach eine Zeile je Ort
    Process {
        id: offsets
        command: ["sh", "-c", "date +%z; for tz; do TZ=\"$tz\" date +%z; done", "sh"].concat(root.locations.map(l => l.timezone))
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root._localOffset = root._minutes(lines[0] ?? "");
                const list = root.locations.map((l, i) => ({
                            "name": l.name,
                            "timezone": l.timezone,
                            "offset": root._minutes(lines[i + 1] ?? "")
                        }));
                list.sort((a, b) => a.offset - b.offset);
                root._clocks = list;
            }
        }
    }

    Component.onCompleted: refresh()
}
