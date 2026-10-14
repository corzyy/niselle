pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0
    readonly property bool usingLua: Hyprland.usingLua

    readonly property bool active: SettingsService.gameMode

    readonly property var options: [
        {
            "path": "decoration:blur:enabled"
        },
        {
            "path": "decoration:motion_blur:enabled"
        },
        {
            "path": "animations:enabled"
        }
    ]

    property var saved: ({})
    property bool reading: false
    property int pending: 0

    function apply(blur, motionBlur, animations) {
        if (!available)
            return;
        if (usingLua) {
            const b = blur ? "true" : "false";
            const m = motionBlur ? "true" : "false";
            const a = animations ? "true" : "false";
            setter.command = ["hyprctl", "eval", `hl.config({decoration={blur={enabled=${b}}, motion_blur={enabled=${m}}}, animations={enabled=${a}}})`];
        } else {
            const b = blur ? "1" : "0";
            const m = motionBlur ? "1" : "0";
            const a = animations ? "1" : "0";
            setter.command = ["sh", "-c", `hyprctl keyword decoration:blur:enabled ${b}; hyprctl keyword decoration:motion_blur:enabled ${m}; hyprctl keyword animations:enabled ${a}`];
        }
        setter.running = true;
    }

    function enable() {
        if (!available || reading)
            return;
        reading = true;
        pending = options.length;
        saved = ({});
        for (const o of options) {
            const p = readerComp.createObject(root, {
                "path": o.path
            });
            p.running = true;
        }
    }

    function disable() {
        if (!available || reading || Object.keys(saved).length === 0)
            return;
        apply(saved["decoration:blur:enabled"] ?? true, saved["decoration:motion_blur:enabled"] ?? true, saved["animations:enabled"] ?? true);
        saved = ({});
    }

    onActiveChanged: active ? enable() : disable()
    onAvailableChanged: if (available && active)
        enable()

    Process {
        id: setter
    }

    Component {
        id: readerComp

        Process {
            id: reader
            property string path
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const j = JSON.parse(text);
                        const raw = j.bool !== undefined ? j.bool : j.int !== undefined ? j.int !== 0 : j.str === "true";
                        root.saved = Object.assign({}, root.saved, {
                            [reader.path]: raw
                        });
                    } catch (e) {}
                    root.pending -= 1;
                    if (root.pending <= 0 && root.reading) {
                        root.reading = false;
                        if (root.active)
                            root.apply(false, false, false);
                        else
                            root.disable();
                    }
                    reader.destroy();
                }
            }
        }
    }

    Component.onCompleted: if (available && active)
        enable()
}
