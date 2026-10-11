import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Unterseite eines Monitors (gnome-control-center display_settings_page): „Aktiviert“-Schalter und die
// Einstellungen des Monitors (DisplaySettingsList). Erreichbar über die Monitorliste der Displays-Seite.
SettingsPage {
    id: root

    readonly property string monitorName: SettingsWindowService.panel.replace("displays/monitor/", "")
    readonly property var monitor: DisplayService.outputs.find(o => o.name === root.monitorName) ?? null
    readonly property bool multi: DisplayService.outputCount > 1

    // ───────── Übernehmen / Verwerfen ─────────
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

    // Aktiviert (nur bei mehreren Monitoren; die letzte aktive Anzeige lässt sich nicht abschalten)
    PrefGroup {
        visible: root.multi && root.monitor !== null

        ActionRow {
            title: root.monitor ? root.monitor.name : ""
            subtitle: DisplayService.enabledOutputs.length <= 1 && DisplayService._d(root.monitor).enabled ? "The last active display cannot be disabled" : "Enable this display"
            ToggleSwitch {
                checked: root.monitor ? DisplayService._d(root.monitor).enabled : false
                enabled: !(DisplayService.enabledOutputs.length <= 1 && root.monitor && DisplayService._d(root.monitor).enabled)
                onToggled: DisplayService.setEnabled(root.monitor.name, checked)
            }
        }
    }

    // Als Primäranzeige festlegen
    PrefGroup {
        visible: root.multi && root.monitor !== null

        ActionRow {
            title: "Primary Display"
            subtitle: DisplayService.primaryName === root.monitorName ? "This is the primary display" : "Contains top bar and Activities"
            Button {
                text: "Make Primary"
                enabled: DisplayService._d(root.monitor).enabled && DisplayService.primaryName !== root.monitorName
                onClicked: DisplayService.setPrimary(root.monitorName)
            }
        }
    }

    PrefGroup {
        visible: root.monitor !== null

        DisplaySettingsList {
            monitor: root.monitor
            allowRefresh: !(DisplayService.outputCount > 1 && DisplayService.configMode === "mirror")
        }
    }
}
