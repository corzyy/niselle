import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

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
