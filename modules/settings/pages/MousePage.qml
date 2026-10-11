import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Maus: Primärtaste, Geschwindigkeit, Beschleunigung und Scrollen (Hyprland input:* über MouseService).
SettingsPage {
    id: root

    readonly property var v: MouseService.values

    PrefGroup {
        title: "General"
        description: "Changes apply immediately and last until the Hyprland configuration is reloaded."

        SegmentedRow {
            title: "Primary Button"
            subtitle: root.v.leftHanded ? "Right" : "Left"
            enabled: MouseService.available
            choices: [
                {
                    "value": false,
                    "label": "Left"
                },
                {
                    "value": true,
                    "label": "Right"
                }
            ]
            value: !!root.v.leftHanded
            onPicked: val => MouseService.set("leftHanded", val)
        }
    }

    PrefGroup {
        title: "Mouse"

        ActionRow {
            title: "Mouse Speed"
            subtitle: (root.v.sensitivity >= 0 ? "+" : "") + root.v.sensitivity.toFixed(2)
            implicitHeight: 64
            Slider {
                implicitWidth: 220
                implicitHeight: 24
                enabled: MouseService.available
                value: root.v.sensitivity + 1
                maximumValue: 2
                onMoved: val => MouseService.set("sensitivity", Math.round((val - 1) * 20) / 20)
            }
        }
        ActionRow {
            title: "Mouse Acceleration"
            subtitle: "Pointer speeds up when moved quickly"
            ToggleSwitch {
                checked: root.v.accelProfile !== "flat"
                enabled: MouseService.available
                onToggled: MouseService.set("accelProfile", checked ? "flat" : "adaptive")
            }
        }
    }

    PrefGroup {
        title: "Scrolling"

        ActionRow {
            title: "Natural Scrolling"
            subtitle: "Scrolling moves the content, not the view"
            ToggleSwitch {
                checked: root.v.naturalScroll
                enabled: MouseService.available
                onToggled: MouseService.set("naturalScroll", !checked)
            }
        }
        ActionRow {
            title: "Scroll Speed"
            subtitle: root.v.scrollFactor.toFixed(1) + "×"
            Button {
                text: "−"
                enabled: MouseService.available && root.v.scrollFactor > 0.2
                onClicked: MouseService.set("scrollFactor", Math.round((root.v.scrollFactor - 0.1) * 10) / 10)
            }
            Button {
                text: "+"
                enabled: MouseService.available && root.v.scrollFactor < 5
                onClicked: MouseService.set("scrollFactor", Math.round((root.v.scrollFactor + 0.1) * 10) / 10)
            }
        }
    }
}
