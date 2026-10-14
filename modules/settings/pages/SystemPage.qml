import QtQuick
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    signal navigate(string panel)

    PrefGroup {
        ActionRow {
            title: "Date & Time"
            icon: "preferences-system-time-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("system/datetime")
        }
        ActionRow {
            title: "Default Apps"
            icon: "starred-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("system/defaultapps")
        }
    }

    PrefGroup {
        ActionRow {
            title: "Matugen Install"
            subtitle: "Set up colour themes for installed programs"
            icon: "applications-graphics-symbolic"
            Button {
                text: "Matugen Install"
                enabled: !MatugenInstallService.running
                onClicked: MatugenInstallService.start()
            }
        }
    }
}
