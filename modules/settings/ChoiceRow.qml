import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

ActionRow {
    id: root

    property var choices: []
    property var value

    signal picked(var value)

    readonly property var currentChoice: {
        for (let i = 0; i < root.choices.length; i++) {
            if (root.choices[i].value === root.value)
                return root.choices[i];
        }
        return null;
    }
    readonly property string currentLabel: root.currentChoice ? root.currentChoice.label : ""

    Item {
        id: trigger
        implicitWidth: contentRow.implicitWidth + 24
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusButton
            color: menu.open ? Theme.alpha(Theme.windowFg, 0.14) : (mouse.containsMouse ? Theme.alpha(Theme.windowFg, 0.10) : Theme.alpha(Theme.windowFg, 0.06))
            border.width: 1
            border.color: Theme.alpha(Theme.windowFg, 0.12)
            opacity: root.enabled ? 1 : Theme.disabledOpacity

            Behavior on color {
                enabled: !Theme.gameMode
                ColorAnimation {
                    duration: Theme.durationMenuItem
                    easing.type: Theme.easeTransition
                }
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentLabel
                color: root.enabled ? Theme.windowFg : Theme.insensitiveFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "pan-down-symbolic"
                color: Theme.alpha(Theme.windowFg, root.enabled ? 0.75 : 0.4)
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled
            onClicked: menu.toggle()
        }

        PopupMenu {
            id: menu

            anchor.item: trigger
            anchor.rect.x: trigger.width + margin - 1
            anchor.rect.y: trigger.height + Theme.popoverRise - margin - 1
            anchor.rect.width: 1
            anchor.rect.height: 1
            anchor.edges: Edges.Bottom | Edges.Right
            anchor.gravity: Edges.Bottom | Edges.Left
            anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip

            Repeater {
                model: root.choices

                PopupMenuItem {
                    required property var modelData
                    ornamented: true
                    ornamentChecked: modelData.value === root.value
                    text: modelData.label
                    onActivated: root.picked(modelData.value)
                }
            }
        }
    }
}
