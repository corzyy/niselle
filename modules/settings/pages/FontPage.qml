import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.services
import qs.components
import ".."

// Schrift: alle installierten Familien nach Kategorie, Auswahl für Oberfläche und Monospace
// (wahlweise gemeinsam). Wird auch an GNOME/GTK (gsettings) weitergegeben, falls vorhanden.
SettingsPage {
    id: root

    // Auswahl gilt für: "both" (eine Schrift für alles), "interface" oder "mono"
    property string target: "both"
    property string query: ""
    property var expanded: ({})
    property var families: []

    readonly property var categoryOrder: ["Sans-serif", "Serif", "Monospace", "Symbols & Emoji"]
    readonly property var categories: {
        const out = {};
        for (const c of root.categoryOrder)
            out[c] = [];
        const q = root.query.trim().toLowerCase();
        for (const f of root.families) {
            if (q !== "" && f.name.toLowerCase().indexOf(q) < 0)
                continue;
            out[f.category].push(f.name);
        }
        return out;
    }

    function categoryOf(name, spacing) {
        if (/symbols|emoji|icons|awesome|dingbats|webdings|wingdings/i.test(name))
            return "Symbols & Emoji";
        if (spacing >= 90 || /\bmono\b|monospace|\bcode\b|courier|consolas/i.test(name))
            return "Monospace";
        if ((/serif/i.test(name) && !/sans/i.test(name)) || /roman|garamond|georgia|times|mincho|myungjo|ming\b|song\b|merriweather|playfair|lora\b|baskerville|palatino|cambria|bookerly|charter/i.test(name))
            return "Serif";
        return "Sans-serif";
    }

    function pick(name) {
        if (root.target !== "mono")
            SettingsService.set("fontFamily", name);
        if (root.target !== "interface")
            SettingsService.set("fontFamilyMono", name);
        root.syncGtk();
    }

    function reset() {
        SettingsService.set("fontFamily", "");
        SettingsService.set("fontFamilyMono", "");
        root.syncGtk();
    }

    // Best effort: GTK-/GNOME-Apps folgen der Auswahl (nur wenn gsettings existiert)
    function syncGtk() {
        gtk.command = ["sh", "-c", 'command -v gsettings >/dev/null 2>&1 || exit 0; s=org.gnome.desktop.interface; if [ -n "$1" ]; then gsettings set $s font-name "$1 11"; gsettings set $s document-font-name "$1 11"; else gsettings reset $s font-name; gsettings reset $s document-font-name; fi; if [ -n "$2" ]; then gsettings set $s monospace-font-name "$2 11"; else gsettings reset $s monospace-font-name; fi', "sh", SettingsService.fontFamily, SettingsService.fontFamilyMono];
        gtk.running = true;
    }

    Process {
        id: gtk
    }

    Process {
        running: true
        command: ["fc-list", "--format", "%{family[0]}|%{spacing}\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const list = [];
                for (const line of text.split("\n")) {
                    const i = line.lastIndexOf("|");
                    const name = (i < 0 ? line : line.slice(0, i)).trim();
                    if (name === "" || name.startsWith(".") || seen[name])
                        continue;
                    seen[name] = true;
                    list.push({
                        "name": name,
                        "category": root.categoryOf(name, i < 0 ? 0 : parseInt(line.slice(i + 1)) || 0)
                    });
                }
                list.sort((a, b) => a.name.localeCompare(b.name));
                root.families = list;
            }
        }
    }

    PrefGroup {
        title: "System Font"
        description: "Interface text across the shell. GTK apps follow when gsettings is available."

        ActionRow {
            title: "Interface"
            subtitle: Theme.fontFamily
            Text {
                text: "Aa"
                color: Theme.windowFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeTitle3
            }
        }
        ActionRow {
            title: "Monospace"
            subtitle: Theme.fontFamilyMono
            Text {
                text: "Aa"
                color: Theme.windowFg
                font.family: Theme.fontFamilyMono
                font.pointSize: Theme.fontSizeTitle3
            }
        }
        ChoiceRow {
            title: "Change"
            subtitle: "Which font the selection below applies to"
            value: root.target
            choices: [
                {
                    "value": "both",
                    "label": "Everything"
                },
                {
                    "value": "interface",
                    "label": "Interface"
                },
                {
                    "value": "mono",
                    "label": "Monospace"
                }
            ]
            onPicked: v => root.target = v
        }
        ActionRow {
            title: "Reset to Default"
            visible: SettingsService.fontFamily !== "" || SettingsService.fontFamilyMono !== ""
            Button {
                text: "Reset"
                onClicked: root.reset()
            }
        }
    }

    Entry {
        Layout.fillWidth: true
        placeholderText: "Search fonts"
        onTextChanged: root.query = text
    }

    Repeater {
        model: root.categoryOrder

        PrefGroup {
            id: group

            required property string modelData
            readonly property var names: root.categories[modelData] ?? []
            readonly property bool open: root.query.trim() !== "" || root.expanded[modelData] === true

            visible: names.length > 0
            title: modelData + " (" + names.length + ")"

            ActionRow {
                title: group.open ? "Hide" : "Show all"
                visible: root.query.trim() === ""
                activatable: true
                suffixIcon: group.open ? "go-up-symbolic" : "go-down-symbolic"
                onActivated: {
                    const e = Object.assign({}, root.expanded);
                    e[group.modelData] = !group.open;
                    root.expanded = e;
                }
            }

            Repeater {
                model: group.open ? group.names : []

                ActionRow {
                    id: row

                    required property string modelData
                    readonly property bool selected: (root.target !== "mono" ? SettingsService.fontFamily : SettingsService.fontFamilyMono) === modelData

                    title: modelData
                    activatable: true
                    suffixIcon: selected ? "object-select-symbolic" : ""
                    onActivated: root.pick(modelData)

                    Text {
                        text: "Aa 123"
                        color: Theme.alpha(Theme.windowFg, 0.8)
                        font.family: row.modelData
                        font.pointSize: Theme.fontSizeBase
                    }
                }
            }
        }
    }
}
