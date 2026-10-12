import QtQuick
import qs

// Anker eines Leisten-Panels: setzt die Karte mittig unter das Element `moduleId` und hält `margin` zu beiden
// Bildschirmrändern ein (übernommen aus corzyy/solstice, style/ui/BarAnchor.qml). Die Bildschirmposition jedes
// Elements veröffentlicht die Leiste über Theme.setBarAnchor (siehe modules/topbar/TopBar.qml); fehlt sie,
// gilt `fallbackX`.
QtObject {
    id: root

    required property string moduleId
    property real panelWidth: 380
    property real screenWidth: 0
    property real margin: 12
    property real fallbackX: 0

    readonly property var anchor: Theme.barAnchor(moduleId)
    readonly property bool valid: anchor !== null
    readonly property real cx: valid ? anchor.x + anchor.w / 2 : fallbackX + panelWidth / 2

    // Zentriert um center, hält margin zu beiden Bildschirmrändern ein
    function clampToScreen(center, size, total) {
        return Math.max(margin, Math.min(center - size / 2, total - size - margin));
    }

    // Linke Kante der Karte
    readonly property real panelX: valid ? clampToScreen(cx, panelWidth, screenWidth) : fallbackX
    // Ankerpunkt (Fenstermitte) für PopupMenu mit Edges.Bottom / Gravity.Bottom
    readonly property real panelCenterX: panelX + panelWidth / 2

    // Verankerungs-Ursprung: drittelt den Bildschirm, damit Panels zum Rand hin öffnen
    readonly property int origin: {
        const third = screenWidth / 3;
        if (cx < third)
            return Item.TopLeft;
        if (cx > screenWidth - third)
            return Item.TopRight;
        return Item.Top;
    }
}
