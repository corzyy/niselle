pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property bool available: _available
    readonly property bool busy: run.running
    readonly property string error: _error

    readonly property var schemes: ["scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-fidelity", "scheme-content", "scheme-neutral", "scheme-monochrome", "scheme-rainbow", "scheme-fruit-salad"]

    readonly property string mode: SettingsService.darkMode ? "dark" : "light"

    function regenerate() {
        root._start(["sh", "-c", 'p=$(awww query 2>/dev/null | sed -n "s/^: $1:.*image: //p" | head -n1); [ -n "$p" ] || p="$2"; [ -n "$p" ] || { echo "no wallpaper found" >&2; exit 2; }; exec matugen image "$p" -t "$3" -m "$4" --prefer saturation', "sh", Theme.primaryScreenName, SettingsService.wallpaper, SettingsService.matugenScheme, root.mode]);
    }

    function fromColor(hex) {
        if (!/^#[0-9a-fA-F]{6}$/.test(hex)) {
            root._error = "invalid colour: " + hex;
            return;
        }
        root._start(["matugen", "color", "hex", hex, "-t", SettingsService.matugenScheme, "-m", root.mode]);
    }

    function applyMode() {
        if (root._available && SettingsService.useMatugen)
            root.regenerate();
        else
            root._applyGtk();
    }

    function _applyGtk() {
        if (gtkApply.running)
            return;
        gtkApply.command = ["sh", "-c", 's="${XDG_CONFIG_HOME:-$HOME/.config}"; h="$s/matugen/post-hook-scripts/gtk-themes-reload.sh"; [ -x "$h" ] && exec "$h" "$1"; true', "sh", root.mode];
        gtkApply.running = true;
    }

    Connections {
        target: SettingsService
        function onDarkModeChanged() {
            root.applyMode();
        }
    }

    function setScheme(type) {
        if (root.schemes.indexOf(type) < 0)
            return;
        SettingsService.set("matugenScheme", type);
        root.regenerate();
    }

    function schemeLabel(type) {
        const n = type.replace(/^scheme-/, "").replace(/-/g, " ");
        return n.charAt(0).toUpperCase() + n.slice(1);
    }

    function init() {
    }

    property bool _available: false
    property string _error: ""

    function _start(command) {
        if (!root._available) {
            root._error = "matugen is not installed";
            return;
        }
        if (run.running)
            return;
        root._error = "";
        run.command = command;
        run.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v matugen >/dev/null && echo yes; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._available = text.trim() === "yes";
                if (root._available && SettingsService.useMatugen && Theme._palette === null)
                    root.regenerate();
            }
        }
    }

    Process {
        id: run
        stderr: StdioCollector {
            id: errors
        }
        onExited: (code, status) => {
            if (code !== 0)
                root._error = errors.text.trim().split("\n").pop() || "matugen failed (" + code + ")";
        }
    }

    Process {
        id: gtkApply
    }

    IpcHandler {
        target: "theme"

        function regenerate(): void {
            root.regenerate();
        }
        function scheme(type: string): void {
            root.setScheme(type);
        }
        function color(hex: string): void {
            root.fromColor(hex);
        }
    }
}
