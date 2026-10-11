import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Eigene Layer-Fläche für ein Overlay über der Übersicht (Suchpanel, App-Ordner): Hyprland kann nur das hinter einer
// Layer-Fläche verwischen, nicht Inhalte derselben Fläche. Die Fläche deckt den Bildschirm ab, ist bis auf den Inhalt
// transparent (nur dessen Pixel werden verwischt) und nimmt Mausereignisse nur im `maskRect` an.
PanelWindow {
    id: root

    required property string layerNamespace
    // Eingabebereich in Fensterkoordinaten (Vorgabe: ganze Fläche)
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
