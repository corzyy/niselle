import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Tastatur: Eingabequellen (Hyprland-Layouts) und Tastenkürzel wie in GNOMEs Einstellungen → Tastatur:
// gegliedert in Niselle und Hyprland (Hyprland weiter in Anwendungen, Fenster, Arbeitsflächen, Lautstärke & Helligkeit,
// Medien, Bildschirmfotos). Ein Klick auf eine Zeile öffnet den „Kürzel festlegen“-Dialog (Esc = abbrechen,
// Rücktaste = abschalten). Katalog und Anwenden: KeybindService.
SettingsPage {
    id: root

    // Eintrag, dessen Kürzel gerade erfasst wird
    property string captureId: ""
    // Erfasste Kombination und ggf. der Eintrag, den sie belegt
    property string captured: ""
    property string capturedConflict: ""
    // Taste ohne nötigen Modifikator gedrückt
    property bool needsModifier: false

    readonly property var captureEntry: KeybindService.entries[captureId]

    function beginCapture(id) {
        captureId = id;
        captured = "";
        capturedConflict = "";
        needsModifier = false;
        KeybindService.captureBegin();
    }

    function endCapture() {
        captureId = "";
        KeybindService.captureEnd();
    }

    // Nie in der Erfassungs-Submap hängen bleiben (Fenster geschlossen, Seite gewechselt, Dialog verschwunden)
    Component.onDestruction: if (captureId !== "")
        KeybindService.captureEnd()
    onVisibleChanged: if (!visible && captureId !== "")
        endCapture()

    function handleKey(event) {
        event.accepted = true;
        if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
            root.endCapture();
            return;
        }
        if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
            KeybindService.set(root.captureId, "");
            root.endCapture();
            return;
        }
        const combo = KeybindService.fromEvent(event.key, event.modifiers, event.nativeScanCode);
        if (combo === "") {
            // nur Modifikatoren: Vorschau der gehaltenen Modifikatoren
            const mods = [];
            if (event.modifiers & Qt.MetaModifier)
                mods.push("SUPER");
            if (event.modifiers & Qt.ControlModifier)
                mods.push("CTRL");
            if (event.modifiers & Qt.AltModifier)
                mods.push("ALT");
            if (event.modifiers & Qt.ShiftModifier)
                mods.push("SHIFT");
            root.captured = mods.join(" + ");
            root.capturedConflict = "";
            root.needsModifier = false;
            return;
        }
        root.captured = combo;
        root.needsModifier = !KeybindService.usable(combo);
        if (root.needsModifier) {
            root.capturedConflict = "";
            return;
        }
        const other = KeybindService.conflict(root.captureId, combo);
        if (other === "") {
            KeybindService.set(root.captureId, combo);
            root.endCapture();
        } else {
            root.capturedConflict = other;
        }
    }

    // Tastenkappe wie GNOMEs Shortcut-Label (.keycap)
    component KeyCap: Rectangle {
        property string label: ""

        implicitWidth: Math.max(26, capText.implicitWidth + 14)
        implicitHeight: 26
        radius: 6
        color: Theme.alpha(Theme.windowFg, Theme.dark ? 0.1 : 0.06)
        border.width: 1
        border.color: Theme.alpha(Theme.windowFg, Theme.dark ? 0.14 : 0.18)

        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.label
            color: Theme.windowFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeCaption
        }
    }

    // Eine Tastenkombination: Kappen mit „+“ dazwischen; leer = „Disabled“
    component Combo: RowLayout {
        property string combo: ""
        property color textColor: Theme.windowFg

        spacing: 4
        Text {
            visible: parent.combo === ""
            text: "Disabled"
            color: Theme.alpha(Theme.windowFg, 0.55)
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
        }
        Repeater {
            model: KeybindService.labels(parent.combo)
            RowLayout {
                required property int index
                required property string modelData
                spacing: 4
                Text {
                    visible: index > 0
                    text: "+"
                    color: Theme.alpha(Theme.windowFg, 0.55)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                }
                KeyCap {
                    label: modelData
                }
            }
        }
    }

    PrefGroup {
        title: "Input Sources"
        description: "Layouts configured in Hyprland. Changes apply immediately."
        visible: KeyboardService.available

        Repeater {
            model: KeyboardService.layouts

            ActionRow {
                required property int index
                required property string modelData
                title: modelData.toUpperCase()
                activatable: KeyboardService.multiple
                suffixIcon: KeyboardService.activeIndex === index ? "object-select-symbolic" : ""
                onActivated: KeyboardService.setLayout(index)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Keyboard Shortcuts"
            color: Theme.windowFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeTitle2
            font.weight: Theme.fontWeightBold
        }
        Button {
            text: "Reset All…"
            enabled: KeybindService.anyOverride
            onClicked: resetDialog.open = true
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: -12
        text: "Click a shortcut to change it. Changes apply immediately and are saved to your Hyprland configuration."
        wrapMode: Text.Wrap
        color: Theme.alpha(Theme.windowFg, 0.55)
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

    Repeater {
        model: KeybindService.categories

        ColumnLayout {
            id: category
            required property var modelData

            Layout.fillWidth: true
            spacing: 24

            Text {
                Layout.fillWidth: true
                text: category.modelData.title
                color: Theme.windowFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeTitle3
                font.weight: Theme.fontWeightBold
            }

            Repeater {
                model: category.modelData.groups

                PrefGroup {
                    id: group
                    required property var modelData
                    title: modelData.title

                    Repeater {
                        model: group.modelData.entries

                        ActionRow {
                            id: row
                            required property var modelData
                            readonly property bool editable: KeybindService.editable(modelData.id) && KeybindService.usingLua

                            title: modelData.title
                            activatable: editable
                            onActivated: root.beginCapture(modelData.id)

                            Combo {
                                combo: KeybindService.combo(row.modelData.id)
                            }
                            Text {
                                visible: row.modelData.alt !== undefined
                                text: "or"
                                color: Theme.alpha(Theme.windowFg, 0.55)
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSizeCaption
                            }
                            Combo {
                                visible: row.modelData.alt !== undefined
                                combo: row.modelData.alt ?? ""
                            }
                            IconButton {
                                visible: KeybindService.customized(row.modelData.id)
                                icon: "edit-undo-symbolic"
                                onClicked: KeybindService.reset(row.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // „Kürzel festlegen“ wie in GNOME: Vorschau der gedrückten Kombination, Hinweis, bei Konflikt Ersetzen
    ModalDialog {
        id: captureDialog
        open: root.captureId !== ""
        title: "Set Shortcut"
        description: root.captureEntry ? "Enter the new shortcut for “" + root.captureEntry.title + "”" : ""
        dialogWidth: 420
        buttons: root.capturedConflict !== "" ? [
            {
                "id": "cancel",
                "text": "Cancel"
            },
            {
                "id": "replace",
                "text": "Replace",
                "primary": true
            }
        ] : [
            {
                "id": "cancel",
                "text": "Cancel"
            }
        ]
        onCanceled: root.endCapture()
        onButtonClicked: id => {
            if (id === "replace")
                KeybindService.set(root.captureId, root.captured);
            root.endCapture();
        }

        // Fängt jede Taste ab (auch Return/Rücktaste), bevor der Dialog sie als Abbruch/OK wertet
        Item {
            Layout.fillWidth: true
            implicitHeight: preview.implicitHeight
            focus: captureDialog.open
            Keys.onPressed: event => root.handleKey(event)

            ColumnLayout {
                id: preview
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Combo {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.captured !== ""
                    combo: root.captured
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.captured === ""
                    text: "Press Esc to cancel or Backspace to disable the keyboard shortcut."
                    color: Theme.alpha(Theme.fgColor, 0.65)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 360
                    visible: root.capturedConflict !== ""
                    text: "Already used for “" + root.capturedConflict + "”. Replacing it will disable that shortcut."
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 360
                    visible: root.needsModifier
                    text: "A modifier such as Super, Ctrl or Alt is required."
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                }
            }
        }
    }

    ModalDialog {
        id: resetDialog
        title: "Reset All Shortcuts?"
        description: "All keyboard shortcuts will be restored to their defaults."
        buttons: [
            {
                "id": "cancel",
                "text": "Cancel"
            },
            {
                "id": "reset",
                "text": "Reset All",
                "primary": true
            }
        ]
        onCanceled: open = false
        onButtonClicked: id => {
            if (id === "reset")
                KeybindService.resetAll();
            open = false;
        }
    }
}
