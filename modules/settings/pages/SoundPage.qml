import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Ton: Ausgabe-/Eingabelautstärke und Geräteauswahl (PipeWire über AudioService).
SettingsPage {
    id: root

    PrefGroup {
        title: "Volume Levels"

        ActionRow {
            title: "Output"
            subtitle: AudioService.sink ? AudioService.displayName(AudioService.sink) : "No output device"
            implicitHeight: 64
            Slider {
                implicitWidth: 220
                implicitHeight: 24
                enabled: AudioService.available
                value: AudioService.volume
                maximumValue: 1.5
                overdriveStart: 1.0
                onMoved: v => AudioService.setVolume(v)
            }
            ToggleSwitch {
                checked: !AudioService.muted
                onToggled: AudioService.setMuted(!checked)
            }
        }
        ActionRow {
            title: "Input"
            subtitle: AudioService.source ? AudioService.displayName(AudioService.source) : "No input device"
            implicitHeight: 64
            visible: AudioService.hasSource
            Slider {
                implicitWidth: 220
                implicitHeight: 24
                value: AudioService.sourceVolume
                onMoved: v => AudioService.setSourceVolume(v)
            }
            ToggleSwitch {
                checked: !AudioService.sourceMuted
                onToggled: AudioService.setSourceMuted(!checked)
            }
        }
    }

    PrefGroup {
        title: "Output Device"
        visible: AudioService.sinks.length > 0

        Repeater {
            model: AudioService.sinks

            ActionRow {
                required property var modelData
                title: AudioService.displayName(modelData)
                activatable: true
                suffixIcon: modelData === AudioService.sink ? "object-select-symbolic" : ""
                onActivated: AudioService.setDefaultSink(modelData)
            }
        }
    }

    PrefGroup {
        title: "Input Device"
        visible: AudioService.sources.length > 0

        Repeater {
            model: AudioService.sources

            ActionRow {
                required property var modelData
                title: AudioService.displayName(modelData)
                activatable: true
                suffixIcon: modelData === AudioService.source ? "object-select-symbolic" : ""
                onActivated: AudioService.setDefaultSource(modelData)
            }
        }
    }
}
