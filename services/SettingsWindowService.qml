pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
