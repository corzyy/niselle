pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0 && Hyprland.usingLua
    readonly property bool wanted: SettingsService.shellBlur && !SettingsService.gameMode

    readonly property string namespaces: "^niselle-(topbar|dock|notifications|osd|clipboard|dialog|search|folder)$"

    property bool created: false

    function apply() {
        if (!available)
            return;
        const on = wanted ? "true" : "false";
        const create = created ? "" : `if NISELLE_BLUR ~= nil then NISELLE_BLUR:set_enabled(false) end; NISELLE_BLUR = hl.layer_rule({name="niselle-blur", match={namespace="${namespaces}"}, blur=true, blur_popups=true, ignore_alpha=0.2}); `;
        created = true;
        setter.command = ["hyprctl", "eval", `${create}NISELLE_BLUR:set_enabled(${on})`];
        setter.running = true;
    }

    onWantedChanged: apply()
    onAvailableChanged: apply()

    Process {
        id: setter
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "configreloaded") {
                created = false;
                reapply.restart();
            }
        }
    }

    Timer {
        id: reapply
        interval: 300
        onTriggered: root.apply()
    }

    Component.onCompleted: apply()
}
