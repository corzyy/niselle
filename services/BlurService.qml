pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland-Blur hinter den Shell-Flächen: eine benannte Layer-Regel auf alle `niselle-*`-Layer, die Inhalte
// zeigen (Desktop, Hot-Corner und Screenshot-Overlay bleiben ohne Blur). `blur_popups` deckt die Popup-Fenster
// der Leiste ab, `ignore_alpha` lässt vollständig transparente Bereiche unberührt. Die Regel wird einmal als
// Lua-Global angelegt und danach nur noch ein-/ausgeschaltet; nach einem Neuladen der Hyprland-Konfiguration
// wird sie neu angelegt. Schatten zeichnet die Shell selbst (ShadowRect), Hyprland kennt keine Layer-Schatten.
// Nur mit Lua-Konfiguration (`hyprctl eval`).
Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0 && Hyprland.usingLua
    // Gamemode schaltet den Compositor-Blur ab (GameModeService), die Regel bleibt dann aus
    readonly property bool wanted: SettingsService.shellBlur && !SettingsService.gameMode

    readonly property string namespaces: "^niselle-(topbar|dock|notifications|osd|switcher|clipboard|dialog|overview|search|folder)$"

    // Wurde die Regel in dieser Sitzung schon angelegt?
    property bool created: false

    function apply() {
        if (!available)
            return;
        const on = wanted ? "true" : "false";
        // Pro Shell-Sitzung einmal neu anlegen (die alte Regel wird abgeschaltet, Hyprland kann Regeln nicht löschen),
        // danach nur noch ein-/ausschalten
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

    // Nach `hyprctl reload` sind Regeln und Globals weg
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
