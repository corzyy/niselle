pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Erzeugt die Farbpalette der Shell mit Matugen. Die Vorlage assets/matugen/niselle-colors.json ist in
// ~/.config/matugen/config.toml eingetragen und schreibt Theme.paletteFile; Theme liest die Datei bei jeder Änderung.
// Jeder matugen-Lauf (auch außerhalb der Shell, z. B. ein Hintergrund-Wähler) färbt die Shell daher um.
// Quelle ist das Hintergrundbild des primären Monitors (`awww query`), sonst die Einstellung wallpaper.
// Schemaart: SettingsService.matugenScheme (matugen -t). Steuerung: `niselle theme regenerate|scheme <typ>|color <hex>`.
Singleton {
    id: root

    // matugen ist installiert
    readonly property bool available: _available
    readonly property bool busy: run.running
    // Letzte Fehlermeldung, "" wenn der letzte Lauf klappte
    readonly property string error: _error

    readonly property var schemes: ["scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-fidelity", "scheme-content", "scheme-neutral", "scheme-monochrome", "scheme-rainbow", "scheme-fruit-salad"]

    // Hell/Dunkel-Stil: matugen erzeugt danach die GTK-Farben (colors.css) und ruft über die post_hooks
    // gtk-themes-reload.sh auf, wodurch auch GTK/systemweit dem Umschalter folgt.
    readonly property string mode: SettingsService.darkMode ? "dark" : "light"

    // Palette aus dem aktuellen Hintergrundbild
    function regenerate() {
        root._start(["sh", "-c", 'p=$(awww query 2>/dev/null | sed -n "s/^: $1:.*image: //p" | head -n1); [ -n "$p" ] || p="$2"; [ -n "$p" ] || { echo "no wallpaper found" >&2; exit 2; }; exec matugen image "$p" -t "$3" -m "$4" --prefer saturation', "sh", Theme.primaryScreenName, SettingsService.wallpaper, SettingsService.matugenScheme, root.mode]);
    }

    // Palette aus einer Farbe ("#rrggbb")
    function fromColor(hex) {
        if (!/^#[0-9a-fA-F]{6}$/.test(hex)) {
            root._error = "invalid colour: " + hex;
            return;
        }
        root._start(["matugen", "color", "hex", hex, "-t", SettingsService.matugenScheme, "-m", root.mode]);
    }

    // Stil auf die GTK-Einstellungen anwenden. Ist matugen verfügbar, erzeugt ein Lauf mit dem passenden
    // Modus die colors.css neu und ruft den Hook auf; sonst wird nur der Hook direkt ausgeführt.
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

    // Dunkel/Hell-Umschalter der Shell → GTK/systemweit übernehmen
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

    // Dienst starten (Singletons laden erst bei erster Verwendung); shell.qml ruft das beim Start auf
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
                // Erster Start: noch keine Palette, dann einmal aus dem Hintergrundbild erzeugen
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

    // Wird nur gebraucht, wenn matugen (oder die Matugen-Farben) aus ist: setzt dann das GTK-Theme hell/dunkel.
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
