import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

PopupMenu {
    id: root

    required property var desktopWindow

    property real clickX: 0
    property real clickY: 0

    function openAt(x, y) {
        root.clickX = x;
        root.clickY = y;
        if (root.open)
            root.anchor.updateAnchor();
        else
            root.show();
    }

    anchor.window: root.desktopWindow
    anchor.rect.x: Math.round(root.clickX - root.margin)
    anchor.rect.y: Math.round(root.clickY - root.margin)
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    arrowSide: Qt.TopEdge

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
