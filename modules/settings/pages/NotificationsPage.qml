import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Notifications: Nicht stören (blendet Banner aus, die Mitteilungen landen weiter im Datumsmenü) und Aufräumen.
SettingsPage {
    id: root

    PrefGroup {
        title: "Banners"

        ActionRow {
            title: "Do Not Disturb"
            subtitle: "Hide notification banners; messages still collect in the date menu"
            ToggleSwitch {
                checked: SettingsService.doNotDisturb
                onToggled: SettingsService.setDoNotDisturb(checked)
            }
        }
    }

    PrefGroup {
        title: "Messages"
        description: NotificationService.count === 0 ? "There are no notifications." : NotificationService.count + (NotificationService.count === 1 ? " notification is waiting in the date menu." : " notifications are waiting in the date menu.")

        ActionRow {
            title: "Clear All"
            icon: "user-trash-symbolic"
            enabled: NotificationService.count > 0
            activatable: true
            onActivated: NotificationService.clearAll()
        }
    }
}
