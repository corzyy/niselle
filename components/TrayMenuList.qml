import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

ColumnLayout {
    id: root

    required property var handle
    property int depth: 0

    spacing: 0

    QsMenuOpener {
        id: opener
        menu: root.handle
    }

    Repeater {
        model: opener.children

        ColumnLayout {
            id: entryRoot

            required property var modelData
            property bool expanded: false

            Layout.fillWidth: true
            spacing: 0

            Separator {
                visible: entryRoot.modelData.isSeparator
                Layout.fillWidth: true
                Layout.topMargin: Theme.basePadding
                Layout.bottomMargin: Theme.basePadding
            }

            PopupMenuItem {
                id: menuItem
                visible: !entryRoot.modelData.isSeparator
                text: (entryRoot.modelData.text ?? "").replace(/_(.)/g, "$1")
                enabled: entryRoot.modelData.enabled
                ornamented: entryRoot.modelData.buttonType !== QsMenuButtonType.None
                ornamentChecked: entryRoot.modelData.checkState === Qt.Checked
                closeOnActivate: !entryRoot.modelData.hasChildren
                Layout.leftMargin: root.depth * Theme.menuOrnamentSize

                onActivated: {
                    if (entryRoot.modelData.hasChildren)
                        entryRoot.expanded = !entryRoot.expanded;
                    else
                        entryRoot.modelData.triggered();
                }

                Icon {
                    visible: entryRoot.modelData.hasChildren
                    name: entryRoot.expanded ? "pan-down-symbolic" : "pan-end-symbolic"
                    color: menuItem.fg
                }
            }

            Loader {
                active: entryRoot.modelData.hasChildren && entryRoot.expanded
                visible: active
                Layout.fillWidth: true
                source: Qt.resolvedUrl("TrayMenuList.qml")
                onLoaded: {
                    item.handle = Qt.binding(() => entryRoot.modelData);
                    item.depth = root.depth + 1;
                }
            }
        }
    }
}
