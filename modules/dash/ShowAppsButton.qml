import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

// „Apps anzeigen“ am rechten Ende des Dash [dash.js:188-271]: 9-Punkte-Raster, Umschalter für das App-Grid.
// Ziehen einer angehefteten App auf den Knopf löst sie vom Dash (Beschriftung „Lösen“, Knopf wird hervorgehoben).
Item {
    id: root

    required property var dash
    readonly property bool menuOpen: menu.open

    readonly property bool canRemove: drop.containsDrag && !!drop.drag.source && drop.drag.source.favorite === true
    readonly property string label: root.canRemove ? "Lösen" : "Apps anzeigen"
    readonly property bool wantsLabel: mouse.containsMouse || root.canRemove
    onWantsLabelChanged: dash.syncLabel(root)
    onCanRemoveChanged: dash.syncLabel(root)

    activeFocusOnTab: true
    Keys.onReturnPressed: OverviewService.toggleApps()
    Keys.onSpacePressed: OverviewService.toggleApps()

    // Mitte des Knopfs in Fensterkoordinaten. Über den Übersichts-Fortschritt neu ausgewertet, damit die
    // Position beim Ein-/Ausblenden des Dash mitwandert; das App-Grid wächst von hier aus auf.
    readonly property point windowCenter: {
        void OverviewService.progress;
        void OverviewService.appsProgress;
        return mapToItem(null, width / 2, height / 2);
    }
    Binding {
        target: OverviewService
        property: "appsOrigin"
        value: root.windowCenter
    }

    DashTile {
        x: 0
        y: (root.height - Theme.dashEdgeOffset - height) / 2
        iconSize: root.dash.iconSizeShown
        hovered: mouse.containsMouse || root.canRemove
        pressed: mouse.pressed
        checked: OverviewService.appsShown
        focused: root.activeFocus

        Icon {
            anchors.fill: parent
            name: "view-app-grid-symbolic"
            size: root.dash.iconSizeShown
            color: Theme.systemFg
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.forceActiveFocus()
        onClicked: mouse => {
            root.dash.hideLabel(root);
            if (mouse.button === Qt.RightButton) {
                menu.toggle();
                return;
            }
            OverviewService.toggleApps();
        }
    }

    // Rechtsklick: Dock-Einstellungen
    PopupMenu {
        id: menu
        arrowSide: Qt.BottomEdge
        anchor.item: root
        anchor.rect.x: root.width / 2
        anchor.rect.y: menu.margin - Theme.popoverRise
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.None

        PopupMenuItem {
            text: "Dock-Einstellungen"
            onActivated: {
                menu.close();
                OverviewService.hide();
                SettingsWindowService.show("appearance/dock");
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["niselle-app"]
        onDropped: dropEvent => {
            const src = dropEvent.source;
            if (src && src.favorite === true && src.entry)
                AppsService.removeFavorite(src.entry);
        }
    }
}
