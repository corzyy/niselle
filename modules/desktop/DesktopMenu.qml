import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Hintergrundmenü (BackgroundMenu) [backgroundMenu.js]: erscheint beim Rechtsklick auf den Desktop.
// Wie in GNOME: „Hintergrund ändern …“, „Anzeigeeinstellungen“ und „Einstellungen“ (Einstellungen-Fenster der Shell),
// dazu „Im Terminal öffnen“. Einträge ohne passende App fehlen (SessionService).
// Die obere linke Ecke der Karte liegt an der Zeigerposition; Slide|Flip hält sie am Bildschirmrand.
PopupMenu {
    id: root

    // Desktop-Fläche, auf der das Menü erscheint (Fenster und Bildschirm)
    required property var desktopWindow

    // Position des Rechtsklicks (Koordinaten im Desktop-Fenster)
    property real clickX: 0
    property real clickY: 0

    // Menü an der Zeigerposition öffnen bzw. dorthin verschieben
    function openAt(x, y) {
        root.clickX = x;
        root.clickY = y;
        if (root.open)
            root.anchor.updateAnchor();
        else
            root.show();
    }

    // Ankerpunkt an der Zeigerposition; die Karte beginnt um `margin` (Schatten) nach innen versetzt
    anchor.window: root.desktopWindow
    anchor.rect.x: Math.round(root.clickX - root.margin)
    anchor.rect.y: Math.round(root.clickY - root.margin)
    anchor.rect.width: 1
    anchor.rect.height: 1
    // Punkt links oben am Anker, Menü klappt nach unten rechts auf
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    arrowSide: Qt.TopEdge

    // Klick außerhalb schließt über den Fokus-Grab. NISELLE_QS_NOGRAB=1 schaltet ihn ab (Screenshots per IPC ohne Klick).
    grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"

    PopupMenuItem {
        visible: SessionService.canOpenSettings
        text: "Hintergrund ändern …"
        onActivated: SessionService.openSettings("background")
    }
    PopupMenuItem {
        visible: SessionService.canOpenSettings
        text: "Anzeigeeinstellungen"
        onActivated: SessionService.openSettings("display")
    }
    PopupMenuItem {
        visible: SessionService.canOpenSettings
        text: "Einstellungen"
        onActivated: SessionService.openSettings("")
    }
    PopupMenuItem {
        visible: SessionService.canOpenTerminal
        text: "Im Terminal öffnen"
        onActivated: SessionService.terminal()
    }
}
