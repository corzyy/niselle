import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// Desktop: transparente Vollbild-Fläche je Monitor auf der Hintergrund-Ebene, unter allen Fenstern und über dem
// Hintergrundbild (awww/swaybg). Rechtsklick öffnet das Hintergrundmenü an der Zeigerposition wie in GNOME.
PanelWindow {
    id: root

    // Steuerung von außen (Tests): quickshell ipc call desktop.<Monitorname> open <x> <y> | close
    IpcHandler {
        target: "desktop." + (root.screen ? root.screen.name : "")

        function open(x: real, y: real): void {
            menu.openAt(x, y);
        }
        function close(): void {
            menu.close();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "niselle-desktop"
    // Nur Zeigerereignisse, kein Tastaturfokus
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: mouse => menu.openAt(mouse.x, mouse.y)
    }

    // Bilddateien auf den Desktop ziehen: in den Bilderordner kopieren und als Hintergrund setzen
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            if (drop.hasUrls) {
                WallpaperService.importAndApply(drop.urls);
                drop.accept(Qt.CopyAction);
            }
        }
    }

    DesktopMenu {
        id: menu
        desktopWindow: root
    }
}
