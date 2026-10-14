import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: root

    required property string layerNamespace
    property rect maskRect: Qt.rect(0, 0, width, height)
    property int keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {
        x: root.maskRect.x
        y: root.maskRect.y
        width: root.maskRect.width
        height: root.maskRect.height
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.keyboardFocus: root.keyboardFocus
}
