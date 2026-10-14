import QtQuick
import qs

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

    function clampToScreen(center, size, total) {
        return Math.max(margin, Math.min(center - size / 2, total - size - margin));
    }

    readonly property real panelX: valid ? clampToScreen(cx, panelWidth, screenWidth) : fallbackX
    readonly property real panelCenterX: panelX + panelWidth / 2

    readonly property int origin: {
        const third = screenWidth / 3;
        if (cx < third)
            return Item.TopLeft;
        if (cx > screenWidth - third)
            return Item.TopRight;
        return Item.Top;
    }
}
