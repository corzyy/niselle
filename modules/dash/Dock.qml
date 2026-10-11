import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Dauerhaftes Dock am unteren Rand (Einstellung „Persistent“): dasselbe Dash wie in der Übersicht, als eigene Ebene.
// Ohne Autohide reserviert es seinen Platz; mit Autohide fährt es aus und erscheint, sobald der Zeiger den unteren Rand berührt
// oder die aktive Arbeitsfläche leer ist.
// Das Fenster hat feste Größe (Dash plus Platz für Tooltip), Eingaben nimmt nur die Pille bzw. der Randstreifen an.
// In der Übersicht ist es ausgeblendet: dort zeigt die Übersicht ihr eigenes Dash.
PanelWindow {
    id: root

    readonly property bool autohide: SettingsService.dockAutohide
    // Platz über der Pille für Tooltip und Menüpfeil
    readonly property real headroom: 48
    readonly property real dockHeight: dash.implicitHeight
    // Aktive Arbeitsfläche dieses Monitors hat kein Fenster (revision: Wechsel zuverlässig neu auswerten)
    readonly property bool workspaceEmpty: {
        void WorkspaceService.revision;
        const mon = root.screen ? Hyprland.monitorFor(root.screen) : WorkspaceService.focusedMonitor;
        const ws = mon ? mon.activeWorkspace : null;
        return !!ws && ws.toplevels.values.length === 0;
    }
    // Autohide: leere Arbeitsfläche, Zeiger auf Pille/Randstreifen, Menü offen oder Ziehen läuft
    readonly property bool wanted: !autohide || workspaceEmpty || hover.hovered || edge.hovered || dash.anyMenuOpen || dash.dragging
    // Kurz nach dem Verschwinden von `wanted` noch sichtbar (peek). Eigene Eigenschaft statt peek.running,
    // sonst hängt `revealed` von dem Timer ab, den es selbst neu startet (Bindungsschleife, Dock blinkt).
    property bool peeking: false
    readonly property bool revealed: wanted || peeking

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: dockHeight + headroom
    exclusionMode: autohide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: autohide ? 0 : dockHeight
    color: "transparent"
    visible: SettingsService.dockPersistent && !OverviewService.visible

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "niselle-dock"

    mask: Region {
        x: slide.x + dash.x + Math.round((dash.width - dash.implicitWidth) / 2)
        y: root.revealed ? root.height - root.dockHeight : root.height - 2
        width: dash.implicitWidth
        height: root.revealed ? root.dockHeight : 2
        // Randstreifen über die ganze Breite, damit der Zeiger das Dock überall am unteren Rand weckt
        Region {
            x: 0
            y: root.height - 2
            width: root.width
            height: 2
        }
    }

    // Kurz sichtbar nach Änderungen, damit das Ausfahren nicht abgeschnitten wird
    Timer {
        id: peek
        interval: 400
        onTriggered: root.peeking = false
    }
    onWantedChanged: {
        if (wanted) {
            peek.stop();
            peeking = false;
        } else {
            peeking = true;
            peek.restart();
        }
    }

    Item {
        id: slide
        width: parent.width
        height: root.dockHeight
        y: root.height - (root.revealed ? root.dockHeight : 0)

        Behavior on y {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeEmphasized
            }
        }

        HoverHandler {
            id: hover
        }

        Dash {
            id: dash
            width: parent.width
            height: root.dockHeight
            maxWidth: root.screen ? root.screen.width : parent.width
            maxHeight: Math.round((root.screen ? root.screen.height : 1000) * Theme.overviewDashMaxHeightRatio)
        }
    }

    // Randstreifen: weckt das ausgeblendete Dock
    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2

        HoverHandler {
            id: edge
        }
    }
}
