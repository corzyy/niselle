import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool selected: false

    readonly property bool hovered: mouse.containsMouse
    signal activated

    implicitHeight: Theme.compact ? 36 : 42
    activeFocusOnTab: true

    Rectangle {
        id: plate
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: Theme.radiusCard
        color: root.selected ? Theme.alpha(Theme.accentColor, Theme.dark ? 0.2 : 0.14) : (mouse.pressed ? Theme.alpha(Theme.windowFg, 0.09) : (root.hovered ? Theme.alpha(Theme.windowFg, 0.06) : Theme.alpha(Theme.windowFg, 0)))
        scale: mouse.pressed ? 0.985 : 1

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationTile
                easing.type: Theme.easeTransition
            }
        }
        Behavior on scale {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationPress
                easing.type: Theme.easeOutCubic
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: Theme.radiusCard
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRing
        opacity: root.activeFocus ? 1 : 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 16
        spacing: 12

        Icon {
            name: root.icon
            color: root.selected ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.85)

            Behavior on color {
                enabled: !Theme.gameMode
                ColorAnimation {
                    duration: Theme.durationTile
                    easing.type: Theme.easeTransition
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            color: root.selected ? Theme.accentColor : Theme.windowFg
            font.weight: root.selected ? Theme.fontWeightBold : Font.Normal
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
    Keys.onReturnPressed: root.activated()
    Keys.onSpacePressed: root.activated()
}
