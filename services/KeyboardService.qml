pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property bool available: layouts.length > 0
    property var layouts: []
    property int activeIndex: 0
    readonly property bool multiple: layouts.length > 1
    readonly property string shortName: layouts[activeIndex] ?? ""

    function refresh() {
        query.running = true;
    }

    function setLayout(index) {
        if (index < 0 || index >= layouts.length)
            return;
        switcher.command = ["hyprctl", "switchxkblayout", "all", String(index)];
        switcher.running = true;
    }

    Process {
        id: switcher
    }

    Component.onCompleted: refresh()

    Connections {
        target: WorkspaceService
        function onEvent(name, data) {
            if (name === "activelayout" || name === "configreloaded")
                root.refresh();
        }
    }

    Process {
        id: query
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards;
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    if (!main)
                        return;
                    root.layouts = main.layout.split(",").map(l => l.trim()).filter(l => l);
                    root.activeIndex = main.active_layout_index ?? 0;
                } catch (e) {
                    root.layouts = [];
                }
            }
        }
    }
}
