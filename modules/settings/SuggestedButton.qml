import QtQuick
import qs

// .suggested-action: Akzent-Textknopf (Donate, …), Radius 8, fett.
Item {
    id: root

    property string text: ""
    readonly property bool hovered: mouse.containsMouse
    signal clicked

    implicitWidth: label.implicitWidth + 2 * 17
    implicitHeight: 34
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusButton
        color: Theme.buttonBg(Theme.buttonState(root.hovered, mouse.pressed, false, root.enabled, root.activeFocus), {
            "bg": Theme.accentColor,
            "fg": Theme.accentFg,
            "style": "default"
        })
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusButton
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRingDefault
        opacity: root.activeFocus ? 1 : 0
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.accentFg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
        font.weight: Theme.fontWeightBold
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
