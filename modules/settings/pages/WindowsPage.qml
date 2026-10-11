import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Fenster (Hyprland): Abstände, Rahmen, Rundung, Deckkraft, Schatten und Blur. Änderungen gelten sofort.
SettingsPage {
    id: root

    readonly property var v: HyprlandLayoutService.values
    readonly property bool ready: HyprlandLayoutService.available

    // Zeile mit Ganzzahl und −/+ am Zeilenende
    component SpinRow: ActionRow {
        id: spin

        property string key
        property int from: 0
        property int to: 100

        subtitle: String(Math.round(root.v[spin.key]))
        Button {
            text: "−"
            enabled: root.ready && root.v[spin.key] > spin.from
            onClicked: HyprlandLayoutService.set(spin.key, root.v[spin.key] - 1)
        }
        Button {
            text: "+"
            enabled: root.ready && root.v[spin.key] < spin.to
            onClicked: HyprlandLayoutService.set(spin.key, root.v[spin.key] + 1)
        }
    }

    component SwitchRow: ActionRow {
        id: sw

        property string key

        ToggleSwitch {
            checked: root.v[sw.key]
            enabled: root.ready
            onToggled: HyprlandLayoutService.set(sw.key, checked)
        }
    }

    PrefGroup {
        description: root.ready ? "" : "Hyprland is not running."

        SpinRow {
            title: "Window Gap"
            key: "gapsIn"
            to: 50
        }
        SpinRow {
            title: "Screen Edge Gap"
            key: "gapsOut"
            to: 100
        }
        SpinRow {
            title: "Border Width"
            key: "borderSize"
            to: 10
        }
        SpinRow {
            title: "Corner Radius"
            key: "rounding"
            to: 40
        }
    }

    PrefGroup {
        ActionRow {
            title: "Inactive Opacity"
            subtitle: Number(root.v.inactiveOpacity).toFixed(2)
            Slider {
                Layout.preferredWidth: 190
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 24
                maximumValue: 1
                value: root.v.inactiveOpacity
                enabled: root.ready
                onMoved: v => HyprlandLayoutService.set("inactiveOpacity", v)
            }
        }
        SwitchRow {
            title: "Shadows"
            key: "shadowEnabled"
        }
        SwitchRow {
            title: "Blur"
            key: "blurEnabled"
        }
    }
}
