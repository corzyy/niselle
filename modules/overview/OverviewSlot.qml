import QtQuick

// Leerer Platz in der Übersicht für eine Unterkomponente (Suche, Arbeitsflächen-Leiste, Fensterbereich, Dash).
//
// Vertrag für den Inhalt:
//   - Kinder werden in die Fläche des Slots gelegt (`anchors.fill: parent` oder eigene Ausrichtung).
//   - Die Höhe des Slots folgt der größten sichtbaren `implicitHeight` der Kinder, wie die bevorzugte Höhe im
//     Layout der Übersicht [overviewControls.js:151-243]. Ein Slot ohne Kinder hat Höhe 0 und nimmt keinen Platz.
//   - Der Slot fängt selbst keine Mausereignisse; ein Klick ins Leere erreicht den Hintergrund und schließt die Übersicht.
//   - Fortschritt, Zustand und Schließen kommen aus OverviewService (progress, shown, hide()).
Item {
    id: root

    default property alias content: box.data

    // Es ist Inhalt vorhanden
    readonly property bool occupied: implicitHeight > 0

    implicitHeight: {
        let h = 0;
        for (const c of box.children) {
            if (c.visible)
                h = Math.max(h, c.implicitHeight);
        }
        return h;
    }

    Item {
        id: box
        anchors.fill: parent
    }
}
