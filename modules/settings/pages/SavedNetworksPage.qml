import QtQuick
import qs
import qs.services
import qs.components
import ".."

// Gespeicherte WLAN-Netze (auch außer Reichweite): automatisch verbinden und entfernen.
SettingsPage {
    id: root

    Component.onCompleted: NetworkService.refreshSaved()

    PrefGroup {
        visible: NetworkService.savedWifi.length === 0

        ActionRow {
            title: "No saved networks"
            subtitle: "Wi-Fi networks you connect to will appear here."
        }
    }

    PrefGroup {
        visible: NetworkService.savedWifi.length > 0
        description: "Networks are joined automatically when in range, if enabled."

        Repeater {
            model: NetworkService.savedWifi

            ActionRow {
                required property var modelData
                title: modelData.name
                subtitle: modelData.active ? "Connected" : ""

                ToggleSwitch {
                    checked: modelData.autoconnect
                    onToggled: NetworkService.setSavedAutoconnect(modelData, checked)
                }
                IconButton {
                    flat: true
                    icon: "user-trash-symbolic"
                    bg: Theme.cardBg
                    onClicked: NetworkService.forgetSaved(modelData)
                }
            }
        }
    }
}
