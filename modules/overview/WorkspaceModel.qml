import QtQuick
import qs
import qs.services

// Arbeitsflächen eines Monitors als stabiles Modell für Leiste und Fensterbereich der Übersicht.
//
// WorkspaceService.workspacesFor() liefert eine neue Liste, in der eine Fläche nur über ihre Position erkannt wird:
// verschwindet eine mittlere Fläche, rutschen die Inhalte aller folgenden Flächen eine Stelle nach vorn und jede
// Ansicht müsste ihren Inhalt tauschen. Dieses Modell führt die Flächen dagegen über ihre ID. Jede Fläche behält ihr
// Delegate; neue Flächen kommen als eigene Zeile hinzu, entfernte bleiben `retain` ms als `gone` im Modell,
// damit das Delegate ausblenden kann, bevor es verschwindet.
//
// Alle Bewegungen in der Übersicht (Gleiten zur aktiven Fläche, Nachrücken, Zuwachs) laufen mit derselben Kurve
// und Dauer (motionSlow, easeOut): Die Versätze `slot - position` heben sich dadurch auch dann auf, wenn Wechsel
// und Umbau gleichzeitig geschehen, und die aktive Fläche springt nie.
Item {
    id: root

    required property var screen

    // Zeilen { wsId, gone }
    readonly property alias model: rows
    // Zeit, die eine entfernte Fläche zum Ausblenden bleibt
    readonly property int retain: Theme.motionSlow + 80

    visible: false

    readonly property var list: {
        void WorkspaceService.revision;
        return WorkspaceService.workspacesFor(screen);
    }
    readonly property int count: list.length

    // Die aktive Fläche; ein kurzzeitiges "keine aktive" (-1 während des Wechsels) wird ignoriert,
    // damit Gleitposition und Nachbarn nicht springen
    readonly property int rawActiveIndex: list.findIndex(w => w.active)
    property int activeIndex: 0
    onRawActiveIndexChanged: {
        if (rawActiveIndex >= 0)
            activeIndex = rawActiveIndex;
    }
    readonly property int activeId: list[activeIndex]?.id ?? -1

    // Gebrochene Mittelposition (Index in `list`), folgt der aktiven Fläche weich
    property real position: activeIndex
    Behavior on position {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    // Zuletzt bekannte Daten je Fläche, auch nach dem Entfernen (zum Ausblenden)
    property var infoMap: ({})
    property var slotMap: ({})

    function infoFor(id) {
        return root.infoMap[id] ?? null;
    }
    // Zielplatz (Index in der Anzeigereihenfolge); entfernte Flächen behalten ihren letzten Platz
    function slotFor(id) {
        return root.slotMap[id] ?? 0;
    }

    ListModel {
        id: rows
    }

    // Entfernt abgelaufene `gone`-Zeilen
    Timer {
        id: purgeTimer
        interval: root.retain
        onTriggered: root._purge()
    }

    onListChanged: root._sync()
    Component.onCompleted: {
        root.activeIndex = Math.max(0, root.rawActiveIndex);
        root._sync();
    }

    function _rowOf(id) {
        for (let i = 0; i < rows.count; i++) {
            if (rows.get(i).wsId === id)
                return i;
        }
        return -1;
    }

    function _sync() {
        const list = root.list;
        const info = {};
        const slots = {};
        for (let i = 0; i < list.length; i++) {
            info[list[i].id] = list[i];
            slots[list[i].id] = i;
        }
        // Zuerst die Karten, damit Delegates beim Anlegen/Aktualisieren ihre Daten finden
        root.infoMap = Object.assign({}, root.infoMap, info);
        root.slotMap = Object.assign({}, root.slotMap, slots);

        // Entfernte Flächen als `gone` markieren, zurückgekehrte wiederbeleben
        let anyGone = false;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            const present = info[r.wsId] !== undefined;
            if (!present && !r.gone) {
                rows.setProperty(i, "gone", true);
                rows.setProperty(i, "goneAt", Date.now());
            } else if (present && r.gone) {
                rows.setProperty(i, "gone", false);
            }
            if (!present)
                anyGone = true;
        }

        // Reihenfolge herstellen: lebende Zeilen in Listenreihenfolge, entfernte bleiben, wo sie sind
        let cursor = 0;
        for (const w of list) {
            while (cursor < rows.count && rows.get(cursor).gone && rows.get(cursor).wsId !== w.id)
                cursor++;
            const at = root._rowOf(w.id);
            if (at < 0)
                rows.insert(cursor, {
                    "wsId": w.id,
                    "gone": false,
                    "goneAt": 0
                });
            else if (at > cursor)
                rows.move(at, cursor, 1);
            cursor++;
        }

        if (anyGone)
            purgeTimer.restart();
    }

    function _purge() {
        const now = Date.now();
        let remaining = false;
        for (let i = rows.count - 1; i >= 0; i--) {
            const r = rows.get(i);
            if (!r.gone)
                continue;
            if (now - r.goneAt >= root.retain - 20) {
                const infoMap = Object.assign({}, root.infoMap);
                const slotMap = Object.assign({}, root.slotMap);
                delete infoMap[r.wsId];
                delete slotMap[r.wsId];
                rows.remove(i);
                root.infoMap = infoMap;
                root.slotMap = slotMap;
            } else {
                remaining = true;
            }
        }
        if (remaining)
            purgeTimer.restart();
    }
}
