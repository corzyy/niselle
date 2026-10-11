import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Shell › Menu Bar: Anordnung und Darstellung der oberen Leiste.
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
        title: "Vitals"
        description: "Values shown in the menu bar. Clicking the item shows all of them."

        ActionRow {
            title: "Processor"
            subtitle: "CPU load"
            ToggleSwitch {
                checked: SettingsService.barVitalsCpu
                onToggled: SettingsService.set("barVitalsCpu", checked)
            }
        }
        ActionRow {
            title: "Memory"
            subtitle: "RAM in use"
            ToggleSwitch {
                checked: SettingsService.barVitalsMemory
                onToggled: SettingsService.set("barVitalsMemory", checked)
            }
        }
        ActionRow {
            title: "Temperature"
            subtitle: "CPU package, if a sensor is found"
            ToggleSwitch {
                checked: SettingsService.barVitalsTemp
                onToggled: SettingsService.set("barVitalsTemp", checked)
            }
        }
        ActionRow {
            title: "Network Speed"
            subtitle: "Download and upload across all interfaces"
            ToggleSwitch {
                checked: SettingsService.barVitalsNet
                onToggled: SettingsService.set("barVitalsNet", checked)
            }
        }
    }

    PrefGroup {
        title: "Updates"
        description: "The Updates item stays hidden until updates are available. Installing asks for your password through polkit."

        ActionRow {
            title: "Check Automatically"
            subtitle: "Look for new updates in the background (dnf)"
            ToggleSwitch {
                checked: SettingsService.updatesAutoCheck
                onToggled: SettingsService.set("updatesAutoCheck", checked)
            }
        }
        ChoiceRow {
            title: "Check Every"
            enabled: SettingsService.updatesAutoCheck
            choices: [1, 3, 6, 12, 24].map(h => ({
                        "value": h,
                        "label": h + (h === 1 ? " hour" : " hours")
                    }))
            value: SettingsService.updatesCheckHours
            onPicked: v => SettingsService.set("updatesCheckHours", v)
        }
        ActionRow {
            title: "Check Now"
            subtitle: UpdateService.checking ? "Checking …" : UpdateService.count + " available"
            enabled: !UpdateService.checking && !UpdateService.installing
            Button {
                text: "Check"
                onClicked: UpdateService.check()
            }
        }
    }

    PrefGroup {
        title: "Audio Visualizer"

        SegmentedRow {
            title: "Bars"
            subtitle: "Shown while media is playing; needs parec"
            choices: [8, 12, 16].map(n => ({
                        "value": n,
                        "label": String(n)
                    }))
            value: SettingsService.barVisualizerBars
            onPicked: v => SettingsService.set("barVisualizerBars", v)
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
            subtitle: "Night light, Thunderbolt, USB tethering, VPN and airplane mode"
            ToggleSwitch {
                checked: SettingsService.showStatusIndicators
                onToggled: SettingsService.set("showStatusIndicators", checked)
            }
        }
    }
}
