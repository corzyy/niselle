import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

Item {
    id: root

    required property var window
    required property var slot
    property bool checked: false

    signal clicked

    x: slot.x
    y: slot.y
    width: slot.width
    height: slot.height

    readonly property var toplevel: Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === root.window.address) ?? null

    Rectangle {
        anchors.fill: parent
        color: Theme.bgColor
        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.window.title
            color: Theme.fgColor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
            opacity: shot.hasContent ? 0 : 0.6
        }
    }

    ScreencopyView {
        id: shot
        anchors.fill: parent
        captureSource: root.toplevel?.wayland ?? null
        live: false
        paintCursor: false
        constraintSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 16
        color: root.checked ? Theme.transparentize(Theme.accentColor, 0.8) : "transparent"
        border.width: 6
        border.color: root.checked ? Theme.accentColor : (mouse.containsMouse ? Theme.darken(Theme.accentColor, 0.15) : "transparent")
        z: 1

        Behavior on border.color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: 200
                easing.type: Theme.easeOut
            }
        }
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: 200
                easing.type: Theme.easeOut
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 48
        height: 48
        radius: 24
        z: 2
        color: root.checked ? Theme.accentColor : "transparent"
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: 200
                easing.type: Theme.easeOut
            }
        }
        Icon {
            anchors.centerIn: parent
            name: "object-select-symbolic"
            size: 24
            color: root.checked ? Theme.accentFg : "transparent"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 3
        onClicked: root.clicked()
    }
}
