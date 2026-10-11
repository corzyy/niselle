import QtQuick
import QtQuick.Layouts
import qs

// Scrollbare Seite wie AdwPreferencesPage: AdwClamp (max. 600px, 12px Rand), 24px Abstand zwischen Gruppen.
Flickable {
    id: root

    default property alias data: column.data
    property real maximumWidth: 600
    property real pageMargin: 16

    contentWidth: width
    contentHeight: column.implicitHeight + topPadding + bottomPadding
    readonly property real topPadding: 24
    readonly property real bottomPadding: 36
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        x: (root.width - width) / 2
        y: root.topPadding
        width: Math.min(root.maximumWidth, root.width) - 2 * root.pageMargin
        spacing: 32
    }

    // Mausrad: 3 Zeilen pro Raste
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const max = Math.max(0, root.contentHeight - root.height);
            const from = scrollAnim.running ? scrollAnim.to : root.contentY;
            const to = Math.max(0, Math.min(max, from - event.angleDelta.y / 2));
            if (Theme.gameMode) {
                root.contentY = to;
                return;
            }
            scrollAnim.stop();
            scrollAnim.to = to;
            scrollAnim.start();
        }
    }

    // Weiches Nachlaufen des Mausrads
    NumberAnimation {
        id: scrollAnim
        target: root
        property: "contentY"
        duration: 220
        easing.type: Theme.easeOutCubic
    }
}
