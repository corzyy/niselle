import QtQuick
import qs

Item {
    id: root

    property string text: ""
    property bool selected: false

    readonly property bool hovered: mouse.containsMouse

    signal activated

    implicitHeight: 34
    width: parent ? parent.width : implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMenuItem
        color: root.hovered ? Theme.alpha(Theme.windowFg, 0.08) : (root.selected ? Theme.alpha(Theme.windowFg, 0.06) : "transparent")
    }

    Rectangle {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: "transparent"
        border.width: 1.5
        border.color: root.selected ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.4)

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Theme.accentColor
            visible: root.selected
        }
    }

    Text {
        x: 40
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 52
        text: root.text
        color: Theme.windowFg
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
}
