import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    PrefGroup {
        title: "Layout"
        boxed: false
        description: "Choose what the menu bar shows and where. Hidden items take no space."

        BarLayoutEditor {
            width: parent.width
        }
    }

    PrefGroup {
        title: "Appearance"

        ActionRow {
            title: "Transparent"
            subtitle: "Remove the bar background"
            ToggleSwitch {
                checked: SettingsService.transparentBar
                onToggled: SettingsService.set("transparentBar", checked)
            }
        }
    }

    PrefGroup {
        title: "Panels"

        ActionRow {
            title: "Attach to Items"
            subtitle: "Open panels directly under their menu bar item and move them with it"
            ToggleSwitch {
                checked: SettingsService.barPanelsFollowItems
                onToggled: SettingsService.set("barPanelsFollowItems", checked)
            }
        }
    }

    PrefGroup {
        title: "Clock"

        SegmentedRow {
            title: "Show"
            choices: [
                {
                    "value": "dateTime",
                    "label": "Date & Time"
                },
                {
                    "value": "time",
                    "label": "Time"
                },
                {
                    "value": "date",
                    "label": "Date"
                }
            ]
            value: SettingsService.barClockFormat
            onPicked: v => SettingsService.set("barClockFormat", v)
        }
    }

    PrefGroup {
        title: "Workspaces"

        SegmentedRow {
            title: "Style"
            subtitle: "How workspaces are drawn"
            choices: [
                {
                    "value": "dots",
                    "label": "Dots"
                },
                {
                    "value": "numbers",
                    "label": "Numbers"
                }
            ]
            value: SettingsService.barWorkspaceStyle
            onPicked: v => SettingsService.set("barWorkspaceStyle", v)
        }
    }

    PrefGroup {
        title: "Active Window"

        ActionRow {
            title: "App Icon"
            subtitle: "Shown unless the name is off too"
            enabled: SettingsService.barAppShowName
            ToggleSwitch {
                checked: SettingsService.barAppShowIcon || !SettingsService.barAppShowName
                onToggled: SettingsService.set("barAppShowIcon", checked)
            }
        }
        ActionRow {
            title: "App Name"
            ToggleSwitch {
                checked: SettingsService.barAppShowName
                onToggled: SettingsService.set("barAppShowName", checked)
            }
        }
    }

    PrefGroup {
        title: "System Menu Icons"

        ActionRow {
            title: "Network"
            ToggleSwitch {
                checked: SettingsService.barShowNetwork
                onToggled: SettingsService.set("barShowNetwork", checked)
            }
        }
        ActionRow {
            title: "Bluetooth"
            subtitle: "While a device is connected"
            ToggleSwitch {
                checked: SettingsService.barShowBluetooth
                onToggled: SettingsService.set("barShowBluetooth", checked)
            }
        }
        ActionRow {
            title: "Volume"
            subtitle: "Scrolling over it still changes the volume"
            ToggleSwitch {
                checked: SettingsService.barShowVolume
                onToggled: SettingsService.set("barShowVolume", checked)
            }
        }
        ActionRow {
            title: "Battery Percentage"
            ToggleSwitch {
                checked: SettingsService.showBatteryPercentage
                onToggled: SettingsService.set("showBatteryPercentage", checked)
            }
        }
        ActionRow {
            title: "Privacy Indicators"
            subtitle: "Camera, microphone, location and screen sharing in use"
            ToggleSwitch {
                checked: SettingsService.showPrivacyIndicators
                onToggled: SettingsService.set("showPrivacyIndicators", checked)
            }
        }
        ActionRow {
            title: "System Status"
            subtitle: "Thunderbolt, USB tethering, VPN and airplane mode"
            ToggleSwitch {
                checked: SettingsService.showStatusIndicators
                onToggled: SettingsService.set("showStatusIndicators", checked)
            }
        }
    }
}
