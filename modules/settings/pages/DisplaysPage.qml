import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Anzeigen wie in GNOME Settings: Anordnungsvorschau (ziehen zum Anordnen), Anzeigeart (Erweitern/Spiegeln),
// Primäranzeige, eine Liste der Monitore mit Unterseite je Monitor und der Einstieg ins Nachtlicht.
// Änderungen laufen über einen Entwurf (DisplayService) und werden mit Leiste „Abbrechen/Übernehmen“ bestätigt.
SettingsPage {
    id: root

    signal navigate(string panel)

    // ───────── Übernehmen / Verwerfen (von SettingsWindow gelesen) ─────────
    readonly property bool showingApplyBar: DisplayService.dirty
    property bool confirmOpen: false
    property int countdown: 20

    function applyConfiguration() {
        DisplayService.apply();
        root.countdown = 20;
        root.confirmOpen = true;
        countdownTimer.restart();
    }
    function cancelConfiguration() {
        DisplayService.cancel();
    }
    function keepChanges() {
        countdownTimer.stop();
        root.confirmOpen = false;
        DisplayService.save();
    }
    function revertChanges() {
        countdownTimer.stop();
        root.confirmOpen = false;
        DisplayService.revertApply();
    }

    // Wird die Seite während der Rückfrage geschlossen, fällt die Anzeige auf den alten Stand zurück
    Component.onDestruction: {
        if (root.confirmOpen)
            DisplayService.revertApply();
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0)
                root.revertChanges();
        }
    }

    ModalDialog {
        open: root.confirmOpen
        title: "Keep Changes?"
        description: "The new display configuration will be reverted in " + root.countdown + " seconds."
        buttons: [
            {
                "id": "revert",
                "text": "Revert Settings"
            },
            {
                "id": "keep",
                "text": "Keep Changes",
                "primary": true
            }
        ]
        onCanceled: root.revertChanges()
        onButtonClicked: id => id === "keep" ? root.keepChanges() : root.revertChanges()
    }

    // ───────── Abgeleitete Werte ─────────
    readonly property bool multi: DisplayService.outputCount > 1
    readonly property bool mirror: DisplayService.configMode === "mirror"
    // Monitor, dessen Einstellungen auf der Hauptseite erscheinen (ein Monitor bzw. Spiegeln)
    readonly property var sourceMonitor: DisplayService.selectedOutput ?? (DisplayService.enabledOutputs.length > 0 ? DisplayService.enabledOutputs[0] : null)

    readonly property var arrangementMonitors: DisplayService.outputs.filter(o => DisplayService._d(o).enabled).map(o => ({
                "name": o.name,
                "number": o.number,
                "x": DisplayService._d(o).x,
                "y": DisplayService._d(o).y,
                "w": DisplayService.logicalWidth(o),
                "h": DisplayService.logicalHeight(o),
                "primary": o.name === DisplayService.primaryName,
                "selected": o.name === DisplayService.selected
            }))

    // ───────── Keine Anzeige ─────────
    PrefGroup {
        visible: DisplayService.loaded && DisplayService.outputCount === 0

        ActionRow {
            title: "No displays found"
            subtitle: "Connect a display to change its settings"
            icon: "video-display-symbolic"
        }
    }

    // ───────── Anzeigeart (nur bei mehreren Monitoren) ─────────
    PrefGroup {
        visible: root.multi

        SegmentedRow {
            title: "Multiple Displays"
            choices: [
                {
                    "value": "join",
                    "label": "Join"
                },
                {
                    "value": "mirror",
                    "label": "Mirror"
                }
            ]
            value: DisplayService.configMode
            onPicked: v => DisplayService.setConfigMode(v)
        }
    }

    // ───────── Anordnung, Primäranzeige, Monitorliste (Erweitern) ─────────
    PrefGroup {
        visible: root.multi && !root.mirror

        // Anordnungsvorschau
        Item {
            Layout.fillWidth: true
            width: parent ? parent.width : 0
            implicitHeight: arrangement.implicitHeight + 2 * 12

            DisplayArrangement {
                id: arrangement
                anchors.fill: parent
                anchors.margins: 12
                monitors: root.arrangementMonitors
                selected: DisplayService.selected
                onMonitorSelected: name => DisplayService.selected = name
                onMonitorMoved: (name, x, y) => DisplayService.setPosition(name, x, y)
            }
        }

        // Primäranzeige
        ChoiceRow {
            title: "Primary Display"
            choices: DisplayService.enabledOutputs.map(o => ({
                        "label": o.name,
                        "value": o.name
                    }))
            value: DisplayService.primaryName
            onPicked: name => DisplayService.setPrimary(name)
        }

        // Ausgewählte Anzeige zur Primäranzeige machen
        ActionRow {
            title: "Make Primary"
            subtitle: "Use the selected display for the top bar and Activities"
            Button {
                text: "Make Primary"
                enabled: DisplayService.selected !== "" && DisplayService.selected !== DisplayService.primaryName
                onClicked: DisplayService.setPrimary(DisplayService.selected)
            }
        }

        // Monitore (Klick öffnet die Unterseite); auch abgeschaltete Anzeigen werden gelistet
        Repeater {
            model: DisplayService.outputs

            ActionRow {
                required property var modelData
                badge: String(modelData.number)
                title: modelData.name
                suffixIcon: "go-next-symbolic"
                activatable: true
                onActivated: {
                    DisplayService.selected = modelData.name;
                    root.navigate("displays/monitor/" + modelData.name);
                }
            }
        }
    }

    // ───────── Monitor-Einstellungen (ein Monitor oder Spiegeln) ─────────
    PrefGroup {
        visible: DisplayService.loaded && root.sourceMonitor !== null && (!root.multi || root.mirror)

        DisplaySettingsList {
            monitor: root.sourceMonitor
            allowRefresh: !root.mirror
        }
    }

    // ───────── Nachtlicht ─────────
    PrefGroup {
        visible: DisplayService.loaded

        ActionRow {
            title: "Night Light"
            subtitle: DisplayService.nightLightActive ? "On" : (SettingsService.nightLight ? "Off (outside schedule)" : "Off")
            icon: "night-light-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("displays/nightlight")
        }
    }
}
