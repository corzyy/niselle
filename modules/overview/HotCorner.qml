import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root

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

    property double hiddenAt: Date.now()

    Connections {
        target: OverviewService
        function onVisibleChanged() {
            if (!OverviewService.visible)
                root.hiddenAt = Date.now();
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && Date.now() - root.hiddenAt > Theme.hotCornerRetriggerDelay)
                OverviewService.toggleByCornerOrButton();
        }
    }
}
