import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: mouse => menu.openAt(mouse.x, mouse.y)
    }

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
