pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Zustand des Einstellungsfensters (modules/settings). Steuerung: `niselle settings [panel]` bzw.
// quickshell ipc call settings open <panel> | close | toggle.
// panel: Bereichs-ID der Seitenleiste ("network", "sound", "system"), Unterseite mit "/" ("system/datetime"); leer = zuletzt.
Singleton {
    id: root

    property bool open: false
    property string panel: "about"

    function show(p) {
        if (p)
            root.panel = p;
        root.open = true;
    }
    function hide() {
        root.open = false;
    }
    function toggle() {
        root.open = !root.open;
    }

    IpcHandler {
        target: "settings"

        function open(panel: string): void {
            root.show(panel);
        }
        function close(): void {
            root.hide();
        }
        function toggle(): void {
            root.toggle();
        }
    }
}
