import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

ColumnLayout {
    id: root

    required property var item

    property var popupRef: null

    property bool expanded: false

    readonly property var menuOwner: root.popupRef

    readonly property string appName: root.item ? (root.item.title || root.item.tooltipTitle || root.item.id || "") : ""
    readonly property string appSubtitle: root.item ? (root.item.tooltipDescription || "") : ""
    readonly property bool hasMenu: root.item ? root.item.hasMenu : false

    Layout.fillWidth: true
    spacing: 0

    signal dismissed

    QsMenuOpener {
        id: opener

        menu: root.hasMenu ? root.item.menu : null
    }

    function activateRow() {
        if (hasMenu) {
            root.expanded = !root.expanded;
        } else if (root.item) {
            root.item.activate();
            if (root.popupRef)
                root.popupRef.close();
        }
    }

    function requestQuit() {
        const wanted = /^(quit|exit|beenden|schließen|schliessen)\b/i;
        for (const entry of opener.children) {
            if (entry.isSeparator || !entry.enabled || entry.hasChildren)
                continue;
            const label = (entry.text || "").replace(/_(.)/g, "$1").replace(/_/g, "").trim();
            if (wanted.test(label)) {
                entry.triggered();
                return;
            }
        }
        root.dismissed();
    }

    Connections {
        target: root.popupRef

        enabled: root.popupRef !== null

        function onOpenChanged() {
            if (!root.popupRef.open)
                root.expanded = false;
        }
    }

    Item {
        id: row

        Layout.fillWidth: true
        implicitHeight: Math.max(content.implicitHeight, Theme.iconSizeLarge) + 2 * Theme.menuItemPaddingV

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMenuItem
            color: {
                if (rowMouse.pressed)
                    return Theme.buttonBg("active", {
                        "bg": Theme.menuItemBg,
                        "style": "flat"
                    });
                if (rowMouse.containsMouse || root.expanded)
                    return Theme.buttonBg("hover", {
                        "bg": Theme.menuItemBg,
                        "style": "flat"
                    });
                return "transparent";
            }

            Behavior on color {
                enabled: !Theme.gameMode
                ColorAnimation {
                    duration: Theme.durationMenuItem
                    easing.type: Theme.easeTransition
                }
            }
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: root.activateRow()
        }

        RowLayout {
            id: content

            anchors.fill: parent
            anchors.leftMargin: Theme.menuItemPaddingH
            anchors.rightMargin: Theme.menuItemPaddingH
            spacing: Theme.menuItemSpacing

            Icon {
                name: root.item ? root.item.icon : ""
                symbolic: false
                size: Theme.iconSizeLarge
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: Theme.fgColor
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeHeading
                    font.weight: Theme.fontWeightBold
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.appSubtitle !== ""
                    text: root.appSubtitle
                    color: Theme.fgColor
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightNormal
                }
            }

            Item {
                id: closeButton

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.iconSize + 2 * Theme.basePadding
                implicitHeight: implicitWidth
                activeFocusOnTab: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusPill
                    color: closeMouse.pressed ? Theme.transparentize(Theme.fgColor, 0.69) : (closeMouse.containsMouse ? Theme.transparentize(Theme.fgColor, 0.78) : Theme.transparentize(Theme.fgColor, 0.87))
                }

                Icon {
                    anchors.centerIn: parent
                    name: "window-close-symbolic"
                    size: Theme.iconSize
                    color: Theme.fgColor
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.requestQuit()
                }
            }
        }
    }

    TrayMenuList {
        Layout.fillWidth: true
        visible: root.expanded && root.hasMenu
        depth: 1
        handle: visible ? root.item.menu : null
    }
}
