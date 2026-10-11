import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Sperrbildschirm: ext-session-lock-v1 (der Compositor zeigt nur noch unsere Flächen und gibt die Tastatur nur uns).
// Im Debug-Modus (NISELLE_LOCK_DEBUG=1) ein gewöhnliches Overlay-Fenster pro Monitor, das sich notfalls per IPC schließen lässt.
Scope {
    WlSessionLock {
        locked: LockService.locked && !LockService.debug

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            LockContent {
                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
            }
        }
    }

    Variants {
        model: LockService.locked && LockService.debug ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "#000000"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "niselle-lock-debug"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockContent {
                anchors.fill: parent
                screenName: modelData.name
            }
        }
    }
}
