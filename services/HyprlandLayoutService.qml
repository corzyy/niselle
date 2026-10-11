pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Fensterlayout und Dekoration über Hyprland: Abstände, Rahmen, Rundung, Deckkraft, Schatten, Blur und
// Bewegungsunschärfe. Werte werden per `hyprctl getoption` gelesen und zur Laufzeit gesetzt
// (Lua: `hyprctl eval`, sonst `keyword`). Gesetzte Werte gelten bis zum Neuladen der Hyprland-Konfiguration.
Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0
    readonly property bool usingLua: Hyprland.usingLua

    // Option → { path (hyprctl-Pfad), kind (int | float | bool | str | css) }; Werte stehen in `values`
    readonly property var options: ({
            // general: Abstände und Rahmen
            "gapsIn": {
                "path": "general:gaps_in",
                "kind": "css"
            },
            "gapsOut": {
                "path": "general:gaps_out",
                "kind": "css"
            },
            "borderSize": {
                "path": "general:border_size",
                "kind": "int"
            },
            "resizeOnBorder": {
                "path": "general:resize_on_border",
                "kind": "bool"
            },
            "layout": {
                "path": "general:layout",
                "kind": "str"
            },
            // decoration: Fenster
            "rounding": {
                "path": "decoration:rounding",
                "kind": "int"
            },
            "roundingPower": {
                "path": "decoration:rounding_power",
                "kind": "float"
            },
            "activeOpacity": {
                "path": "decoration:active_opacity",
                "kind": "float"
            },
            "inactiveOpacity": {
                "path": "decoration:inactive_opacity",
                "kind": "float"
            },
            "fullscreenOpacity": {
                "path": "decoration:fullscreen_opacity",
                "kind": "float"
            },
            "dimInactive": {
                "path": "decoration:dim_inactive",
                "kind": "bool"
            },
            "dimStrength": {
                "path": "decoration:dim_strength",
                "kind": "float"
            },
            // decoration: Schatten
            "shadowEnabled": {
                "path": "decoration:shadow:enabled",
                "kind": "bool"
            },
            "shadowRange": {
                "path": "decoration:shadow:range",
                "kind": "int"
            },
            "shadowRenderPower": {
                "path": "decoration:shadow:render_power",
                "kind": "int"
            },
            // decoration: Blur
            "blurEnabled": {
                "path": "decoration:blur:enabled",
                "kind": "bool"
            },
            "blurVariant": {
                "path": "decoration:blur:variant",
                "kind": "int"
            },
            "blurSize": {
                "path": "decoration:blur:size",
                "kind": "int"
            },
            "blurPasses": {
                "path": "decoration:blur:passes",
                "kind": "int"
            },
            "blurVibrancy": {
                "path": "decoration:blur:vibrancy",
                "kind": "float"
            },
            // decoration: Bewegungsunschärfe
            "motionBlur": {
                "path": "decoration:motion_blur:enabled",
                "kind": "bool"
            },
            // dwindle
            "preserveSplit": {
                "path": "dwindle:preserve_split",
                "kind": "bool"
            }
        })
    readonly property var layouts: ["dwindle", "master", "scrolling", "monocle"]

    property var values: ({
            "gapsIn": 5,
            "gapsOut": 20,
            "borderSize": 2,
            "resizeOnBorder": false,
            "layout": "dwindle",
            "rounding": 10,
            "roundingPower": 2,
            "activeOpacity": 1,
            "inactiveOpacity": 1,
            "fullscreenOpacity": 1,
            "dimInactive": false,
            "dimStrength": 0.5,
            "shadowEnabled": true,
            "shadowRange": 4,
            "shadowRenderPower": 3,
            "blurEnabled": true,
            "blurVariant": 0,
            "blurSize": 3,
            "blurPasses": 1,
            "blurVibrancy": 0.17,
            "motionBlur": true,
            "preserveSplit": true
        })

    // Lua-Literal eines Werts (bool → true/false, str → "…", sonst die Zahl)
    function _luaValue(kind, value) {
        if (kind === "bool")
            return value ? "true" : "false";
        if (kind === "str")
            return JSON.stringify(value);
        return String(value);
    }

    // `decoration:shadow:enabled` → hl.config({decoration={shadow={enabled=<lit>}}})
    function _luaExpr(path, lit) {
        const parts = path.split(":");
        let expr = lit;
        for (let i = parts.length - 1; i >= 0; i--)
            expr = "{" + parts[i] + "=" + expr + "}";
        return "hl.config(" + expr + ")";
    }

    function set(key, value) {
        const o = root.options[key];
        if (!o)
            return;
        const v = Object.assign({}, root.values);
        v[key] = value;
        root.values = v;
        if (root.usingLua) {
            setter.command = ["hyprctl", "eval", root._luaExpr(o.path, root._luaValue(o.kind, value))];
        } else {
            const kw = o.kind === "bool" ? (value ? "1" : "0") : String(value);
            setter.command = ["hyprctl", "keyword", o.path, kw];
        }
        setter.running = true;
    }

    function refresh() {
        for (const key of Object.keys(root.options)) {
            const o = root.options[key];
            const p = readerComp.createObject(root, {
                "key": key,
                "command": ["hyprctl", "getoption", o.path, "-j"]
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
                        let raw;
                        if (kind === "str")
                            raw = j.str;
                        else if (kind === "bool")
                            raw = j.bool;
                        else if (kind === "float")
                            raw = j.float !== undefined ? parseFloat(j.float) : undefined;
                        else if (kind === "css")
                            raw = j.css !== undefined ? parseInt(j.css, 10) : undefined;
                        else
                            raw = j.int;
                        if (raw !== undefined && !(typeof raw === "number" && isNaN(raw))) {
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
