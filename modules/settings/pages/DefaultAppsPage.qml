import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Standardanwendungen je Kategorie. Klick auf eine Kategorie klappt die passenden Anwendungen auf;
// die Auswahl wird mit xdg-mime gesetzt (DefaultAppsService).
SettingsPage {
    id: root

    property string expanded: ""

    function appName(id) {
        return AppsService.byId(id)?.name ?? id.replace(/\.desktop$/, "");
    }

    PrefGroup {
        description: "Choose the app that opens each kind of link or file."

        Repeater {
            model: DefaultAppsService.categories

            Column {
                id: block

                required property var modelData
                required property int index
                readonly property string current: DefaultAppsService.currentId(modelData)
                readonly property bool open: root.expanded === modelData.id

                width: parent.width

                ActionRow {
                    title: block.modelData.title
                    subtitle: block.current ? root.appName(block.current) : "None"
                    icon: block.modelData.icon
                    suffixIcon: block.open ? "pan-up-symbolic" : "pan-down-symbolic"
                    activatable: true
                    onActivated: root.expanded = block.open ? "" : block.modelData.id
                }

                Repeater {
                    model: block.open ? DefaultAppsService.candidates(block.modelData) : []

                    ActionRow {
                        required property string modelData
                        readonly property var entry: AppsService.byId(modelData)
                        title: root.appName(modelData)
                        icon: entry?.icon || "application-x-executable"
                        iconSymbolic: false
                        activatable: true
                        suffixIcon: modelData === block.current ? "object-select-symbolic" : ""
                        onActivated: DefaultAppsService.setDefault(block.modelData, modelData)
                    }
                }
            }
        }
    }
}
