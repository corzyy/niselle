pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Gamemode: schaltet in Hyprland den Fenster- und Bewegungs-Blur sowie alle Animationen ab, um GPU-Last zu senken.
// Beim Einschalten werden die aktuellen Werte gelesen und gemerkt, beim Ausschalten wiederhergestellt.
// Werte werden zur Laufzeit per `hyprctl` gesetzt (Lua: `hyprctl eval`, sonst `keyword`) und gelten bis zum
// Neuladen der Hyprland-Konfiguration. Die Shell-Animationen und -Schatten hängen an Theme.gameMode, das in
// shell.qml an SettingsService.gameMode gebunden ist.
Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0
    readonly property bool usingLua: Hyprland.usingLua

    // An SettingsService.gameMode gebundenes Zustandssignal
    readonly property bool active: SettingsService.gameMode

    // Optionen, die Gamemode abschaltet (Hyprland-Pfad für getoption/keyword)
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

    // Gemerkte Werte vor dem Einschalten (Hyprland-Pfad → bool)
    property var saved: ({})
    // Läuft noch das Auslesen der aktuellen Werte?
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

    // Aktuelle Werte merken, danach Blur und Animationen abschalten
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

    // Gemerkte Werte wiederherstellen
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
                        // Beim Ausschalten noch während des Lesens die gemerkten Werte zurücknehmen
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
