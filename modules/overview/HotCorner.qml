import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Heiße Ecke oben links [layout.js HotCorner]: Mauszeiger in der Ecke schaltet die Übersicht.
// Wie in GNOME hat nur ein Monitor eine Ecke, an dessen oberer linker Ecke kein anderer Monitor anschließt.
PanelWindow {
    id: root

    // Kein Monitor links oder oberhalb der Ecke
    readonly property bool hasCorner: {
        const s = root.screen;
        if (!s)
            return false;
        for (const o of Quickshell.screens) {
            if (o.name === s.name)
                continue;
            const covers = (x, y) => x >= o.x && x < o.x + o.width && y >= o.y && y < o.y + o.height;
            if (covers(s.x - 1, s.y) || covers(s.x, s.y - 1))
                return false;
        }
        return true;
    }

    anchors {
        top: true
        left: true
    }
    implicitWidth: Theme.hotCornerSize
    implicitHeight: Theme.hotCornerSize
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: hasCorner

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-hot-corner"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Zeitpunkt (ms), zu dem die Übersicht zuletzt verschwunden ist
    property double hiddenAt: Date.now()

    Connections {
        target: OverviewService
        function onVisibleChanged() {
            if (!OverviewService.visible)
                root.hiddenAt = Date.now();
        }
    }

    // Auslösen nur, wenn der Zeiger die Ecke wirklich betritt, nicht wenn die Übersicht unter ihm verschwindet
    HoverHandler {
        onHoveredChanged: {
            if (hovered && Date.now() - root.hiddenAt > Theme.hotCornerRetriggerDelay)
                OverviewService.toggleByCornerOrButton();
        }
    }
}
