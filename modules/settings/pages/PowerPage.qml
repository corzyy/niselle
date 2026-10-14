import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    readonly property var lockChoices: [60, 120, 300, 600, 900, 1800]
    readonly property var suspendChoices: [300, 600, 900, 1800, 3600, 7200]

    function minutes(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? (m / 60) + " h" : m + " min";
    }

    PrefGroup {
        title: "Power Mode"
        visible: PowerService.profilesAvailable

        Repeater {
            model: PowerService.profiles

            ActionRow {
                required property string modelData
                title: modelData === "power-saver" ? "Power Saver" : modelData === "performance" ? "Performance" : "Balanced"
                subtitle: modelData === "power-saver" ? "Reduced performance and power usage" : modelData === "performance" ? "High performance and power usage" : "Standard performance and power usage"
                activatable: true
                suffixIcon: PowerService.profile === modelData ? "object-select-symbolic" : ""
                onActivated: PowerService.setProfile(modelData)
            }
        }
    }

    PrefGroup {
        title: "Screen Lock"

        ActionRow {
            title: "Automatic Screen Lock"
            subtitle: "Lock the screen when the computer has been idle"
            ToggleSwitch {
                checked: SettingsService.idleLockEnabled
                onToggled: SettingsService.set("idleLockEnabled", checked)
            }
        }
        ChoiceRow {
            title: "Lock After"
            enabled: SettingsService.idleLockEnabled
            choices: root.lockChoices.map(s => ({
                        "value": s,
                        "label": root.minutes(s)
                    }))
            value: SettingsService.idleLockDelay
            onPicked: v => SettingsService.set("idleLockDelay", v)
        }
        ActionRow {
            title: "Lock Now"
            icon: "system-lock-screen-symbolic"
            activatable: true
            onActivated: SessionService.lock()
        }
    }

    PrefGroup {
        title: "Suspend"

        ActionRow {
            title: "Automatic Suspend"
            subtitle: SessionService.canSuspend ? "Put the computer to sleep when it has been idle" : "Suspend is not available on this system"
            enabled: SessionService.canSuspend
            ToggleSwitch {
                checked: SettingsService.idleSuspendEnabled
                onToggled: SettingsService.set("idleSuspendEnabled", checked)
            }
        }
        ChoiceRow {
            title: "Suspend After"
            enabled: SessionService.canSuspend && SettingsService.idleSuspendEnabled
            choices: root.suspendChoices.map(s => ({
                        "value": s,
                        "label": root.minutes(s)
                    }))
            value: SettingsService.idleSuspendDelay
            onPicked: v => SettingsService.set("idleSuspendDelay", v)
        }
        ActionRow {
            title: "Lock Before Suspend"
            subtitle: "Require the password after waking up"
            ToggleSwitch {
                checked: SettingsService.lockBeforeSuspend
                onToggled: SettingsService.set("lockBeforeSuspend", checked)
            }
        }
        ActionRow {
            title: "Suspend Now"
            icon: "weather-clear-night-symbolic"
            enabled: SessionService.canSuspend
            activatable: true
            onActivated: SessionService.suspend()
        }
    }

    PrefGroup {
        title: "Caffeine"
        description: "Playing video also keeps the computer awake. Caffeine is switched off again when the shell restarts."

        ActionRow {
            title: "Keep Awake"
            subtitle: "Do not lock or suspend automatically"
            ToggleSwitch {
                checked: IdleService.caffeine
                onToggled: IdleService.setCaffeine(checked)
            }
        }
    }
}
