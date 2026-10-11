import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Shell › Dock: Größe, dauerhafte Anzeige und Autohide des Docks (Dash mit angehefteten und laufenden Apps).
SettingsPage {
    id: root

    PrefGroup {
        title: "Dock"

        ChoiceRow {
            title: "Icon Size"
            subtitle: "Largest icon size, smaller if the screen is too narrow"
            choices: Theme.dashIconSizes.map(s => ({
                        "value": s,
                        "label": String(s)
                    }))
            value: SettingsService.dockIconSize
            onPicked: v => SettingsService.set("dockIconSize", v)
        }
        ActionRow {
            title: "Persistent"
            subtitle: "Keep the dock on the desktop, not only in the overview"
            ToggleSwitch {
                checked: SettingsService.dockPersistent
                onToggled: SettingsService.set("dockPersistent", checked)
            }
        }
        ActionRow {
            title: "Auto-hide"
            subtitle: "Hide the dock until the pointer touches the bottom edge"
            enabled: SettingsService.dockPersistent
            ToggleSwitch {
                checked: SettingsService.dockAutohide
                onToggled: SettingsService.set("dockAutohide", checked)
            }
        }
    }
}
