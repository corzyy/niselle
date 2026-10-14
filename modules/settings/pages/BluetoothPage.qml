import QtQuick
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    Component.onCompleted: BluetoothService.requestDiscovery("settings.bluetooth")
    Component.onDestruction: BluetoothService.releaseDiscovery("settings.bluetooth")

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
