import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Item {
    id: root

    property string title: ""
    property bool checked: false

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property string buttonState: Theme.buttonState(hovered, pressed, false, enabled, activeFocus)

    signal clicked

    implicitWidth: Theme.quickToggleWidth
    implicitHeight: Theme.backgroundAppsToggleHeight
    activeFocusOnTab: true
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.buttonState === "normal" ? "transparent" : Theme.buttonBg(root.buttonState, {})
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRing
        opacity: root.activeFocus ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.quickToggleIconLeading
        anchors.rightMargin: Theme.quickToggleHPadding
        spacing: Theme.quickToggleSpacing

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.fgColor
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeHeading
            font.weight: Theme.fontWeightBold
        }

        Icon {
            name: "go-next-symbolic"
            size: Theme.iconSize
            color: Theme.fgColor
        }
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
