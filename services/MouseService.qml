pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Mauseinstellungen über Hyprland (input:*): Geschwindigkeit, Beschleunigung, Scrollen, Primärtaste.
// Werte werden per `hyprctl getoption` gelesen und zur Laufzeit gesetzt (Lua: `hyprctl eval`, sonst `keyword`).
// Gesetzte Werte gelten bis zum Neuladen der Hyprland-Konfiguration.
Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0
    readonly property bool usingLua: Hyprland.usingLua

    // Option → { name, kind } ; Werte stehen in `values`
    readonly property var options: ({
            "sensitivity": {
                "name": "sensitivity",
                "kind": "float"
            },
            "accelProfile": {
                "name": "accel_profile",
                "kind": "str"
            },
            "naturalScroll": {
                "name": "natural_scroll",
                "kind": "bool"
            },
            "scrollFactor": {
                "name": "scroll_factor",
                "kind": "float"
            },
            "leftHanded": {
                "name": "left_handed",
                "kind": "bool"
            }
        })

    property var values: ({
            "sensitivity": 0,
            "accelProfile": "",
            "naturalScroll": false,
            "scrollFactor": 1,
            "leftHanded": false
        })

    function set(key, value) {
        const o = root.options[key];
        if (!o)
            return;
        const v = Object.assign({}, root.values);
        v[key] = value;
        root.values = v;
        const lit = o.kind === "str" ? JSON.stringify(value) : String(value);
        setter.command = root.usingLua ? ["hyprctl", "eval", `hl.config({input={${o.name}=${lit}}})`] : ["hyprctl", "keyword", `input:${o.name}`, String(value)];
        setter.running = true;
    }

    function refresh() {
        for (const key of Object.keys(root.options)) {
            const p = readerComp.createObject(root, {
                "key": key,
                "command": ["hyprctl", "getoption", `input:${root.options[key].name}`, "-j"]
            });
            p.running = true;
        }
    }

    Process {
        id: setter
    }

    Component {
        id: readerComp

        Process {
            id: reader
            property string key
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const j = JSON.parse(text);
                        const kind = root.options[reader.key].kind;
                        const raw = kind === "str" ? j.str : kind === "bool" ? j.bool : kind === "float" ? j.float : j.int;
                        if (raw !== undefined) {
                            const v = Object.assign({}, root.values);
                            v[reader.key] = raw;
                            root.values = v;
                        }
                    } catch (e) {}
                    reader.destroy();
                }
            }
        }
    }

    Component.onCompleted: refresh()

    Connections {
        target: WorkspaceService
        function onEvent(name, data) {
            if (name === "configreloaded")
                root.refresh();
        }
    }
}
