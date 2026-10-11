pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Tastaturlayouts über Hyprland: Liste der konfigurierten Layouts und das aktive.
// Aktualisierung nur bei Hyprland-Ereignissen (activelayout, configreloaded), kein Polling.
Singleton {
    id: root

    // Hyprland antwortet und kennt eine Tastatur
    readonly property bool available: layouts.length > 0
    // Kurznamen der Layouts in Konfigurationsreihenfolge, z. B. ["de", "us"]
    property var layouts: []
    property int activeIndex: 0
    // Mehrere Layouts: GNOME zeigt die Anzeige nur dann
    readonly property bool multiple: layouts.length > 1
    // Kurzname des aktiven Layouts wie in GNOME ("de")
    readonly property string shortName: layouts[activeIndex] ?? ""

    function refresh() {
        query.running = true;
    }

    // Layout nach Index aktivieren (für alle Tastaturen); die Anzeige zieht über das Hyprland-Ereignis nach
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
