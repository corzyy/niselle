import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

PanelWindow {
    id: root

    readonly property bool autohide: SettingsService.dockAutohide
    readonly property real headroom: 48
    readonly property real dockHeight: dash.implicitHeight
    readonly property bool workspaceEmpty: {
        void WorkspaceService.revision;
        const mon = root.screen ? Hyprland.monitorFor(root.screen) : WorkspaceService.focusedMonitor;
        const ws = mon ? mon.activeWorkspace : null;
        return !!ws && ws.toplevels.values.length === 0;
    }
    readonly property bool wanted: !autohide || workspaceEmpty || hover.hovered || edge.hovered || dash.anyMenuOpen || dash.dragging
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
        Region {
            x: 0
            y: root.height - 2
            width: root.width
            height: 2
        }
    }

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

    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2

        HoverHandler {
            id: edge
        }
    }
}
