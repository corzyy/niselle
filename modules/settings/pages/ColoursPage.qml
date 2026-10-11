import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Farben: Palette aus dem Hintergrundbild (Matugen), Schema und feste Akzentfarbe.
// Eigene Seite der Einstellungen (Seitenleiste „Colours“), zuvor Teil von Appearance.
SettingsPage {
    id: root

    PrefGroup {
        title: "Colours"
        description: MatugenService.available ? "" : "Matugen is not installed."

        ActionRow {
            title: "Wallpaper Colours"
            subtitle: "Generate the shell palette from the wallpaper with Matugen"
            ToggleSwitch {
                enabled: MatugenService.available
                checked: SettingsService.useMatugen
                onToggled: SettingsService.set("useMatugen", checked)
            }
        }
        ActionRow {
            title: "Regenerate"
            subtitle: MatugenService.error !== "" ? MatugenService.error : (MatugenService.busy ? "Generating…" : (Theme.matugenActive ? "Palette from " + MatugenService.schemeLabel(SettingsService.matugenScheme) + " scheme" : "No palette generated yet"))
            visible: SettingsService.useMatugen
            Button {
                text: "Regenerate"
                enabled: MatugenService.available && !MatugenService.busy
                onClicked: MatugenService.regenerate()
            }
        }
    }

    PrefGroup {
        title: "Scheme"
        visible: SettingsService.useMatugen && MatugenService.available

        Repeater {
            model: MatugenService.schemes

            ActionRow {
                required property string modelData
                title: MatugenService.schemeLabel(modelData)
                activatable: true
                suffixIcon: SettingsService.matugenScheme === modelData ? "object-select-symbolic" : ""
                onActivated: MatugenService.setScheme(modelData)
            }
        }
    }

    PrefGroup {
        title: "Accent Colour"
        visible: !SettingsService.useMatugen || !Theme.matugenActive

        Item {
            width: parent.width
            implicitHeight: 60

            Row {
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: Object.keys(Theme.accents)

                    Rectangle {
                        id: swatch

                        required property string modelData
                        width: 32
                        height: 32
                        radius: 16
                        color: Theme.accents[modelData]
                        border.width: Theme.accent === modelData ? 3 : 0
                        border.color: Theme.alpha(Theme.windowFg, 0.5)

                        Icon {
                            anchors.centerIn: parent
                            visible: Theme.accent === swatch.modelData
                            name: "object-select-symbolic"
                            color: "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Theme.accent = swatch.modelData
                        }
                    }
                }
            }
        }
    }
}
