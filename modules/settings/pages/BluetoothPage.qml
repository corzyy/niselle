import QtQuick
import qs
import qs.services
import qs.components
import ".."

// Bluetooth: Schalter, gekoppelte Geräte und Geräte in der Nähe (BluetoothService).
// Solange die Seite sichtbar ist, läuft die Suche nach Geräten in der Nähe.
SettingsPage {
    id: root

    // Suche anfordern, sobald die Seite geladen ist, und beim Verlassen wieder freigeben
    Component.onCompleted: BluetoothService.requestDiscovery("settings.bluetooth")
    Component.onDestruction: BluetoothService.releaseDiscovery("settings.bluetooth")

    // Adapter wird auf der Seite ein-/ausgeschaltet: Suche entsprechend nachführen
    Connections {
        target: BluetoothService

        function onEnabledChanged() {
            if (BluetoothService.enabled)
                BluetoothService.requestDiscovery("settings.bluetooth");
            else
                BluetoothService.releaseDiscovery("settings.bluetooth");
        }
    }

    PrefGroup {
        ActionRow {
            title: "Bluetooth"
            subtitle: BluetoothService.available ? (BluetoothService.enabled ? "Visible as “" + AboutService.deviceName + "”" : "Off") : "No Bluetooth adapter found"
            ToggleSwitch {
                enabled: BluetoothService.available
                checked: BluetoothService.enabled
                onToggled: BluetoothService.setEnabled(checked)
            }
        }
    }

    // Gekoppelte Geräte
    PrefGroup {
        title: "Devices"
        visible: BluetoothService.enabled && BluetoothService.pairedDevices.length > 0

        Repeater {
            model: BluetoothService.pairedDevices

            ActionRow {
                required property var modelData
                icon: (modelData.icon || "bluetooth") + "-symbolic"
                title: modelData.name
                subtitle: modelData.connected ? "Connected" : "Paired"
                activatable: true
                onActivated: BluetoothService.toggleDevice(modelData)
            }
        }
    }

    // Während der Suche entdeckte Geräte, die noch nicht gekoppelt sind
    PrefGroup {
        title: "Nearby Devices"
        visible: BluetoothService.enabled

        Repeater {
            model: BluetoothService.nearbyDevices

            ActionRow {
                required property var modelData
                icon: (modelData.icon || "bluetooth") + "-symbolic"
                title: modelData.name
                subtitle: "Not Set Up"
                activatable: true
                onActivated: BluetoothService.toggleDevice(modelData)
            }
        }

        ActionRow {
            visible: BluetoothService.nearbyDevices.length === 0
            title: "Searching for devices…"
            Spinner {
                running: BluetoothService.discoveryRequested
                color: Theme.windowFg
            }
        }
    }
}
