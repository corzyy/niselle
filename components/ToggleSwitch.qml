import QtQuick
import qs

// .toggle-switch [_switches.scss:1-53]: 46 × 26px, Griff 20px mit 3px Rand, Übergang 100 ms.
Item {
    id: root

    property bool checked: false

    readonly property bool hovered: mouse.containsMouse

    signal toggled

    implicitWidth: Theme.switchWidth
    implicitHeight: Theme.switchHeight
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: {
            if (root.checked)
                return root.hovered ? Theme.lighten(Theme.accentColor, 0.05) : Theme.accentColor;
            return root.hovered ? Theme.switchBgHover : Theme.switchBg;
        }

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationSwitch
                easing.type: Theme.easeTransition
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRing
        opacity: root.activeFocus ? 1 : 0
    }

    ShadowRect {
        x: root.checked ? root.width - Theme.switchHandleMargin - width : Theme.switchHandleMargin
        y: Theme.switchHandleMargin
        width: Theme.switchHandleSize
        height: Theme.switchHandleSize
        radius: Theme.radiusPill
        color: root.checked ? Theme.switchHandleChecked : Theme.switchHandle
        shadowColor: Theme.switchHandleShadow
        shadowBlur: Theme.shadowHandleBlur
        shadowOffsetY: Theme.shadowHandleY

        Behavior on x {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationSwitch
                easing.type: Theme.easeTransition
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            root.checked = !root.checked;
            root.toggled();
        }
    }

    Keys.onReturnPressed: mouse.clicked(null)
    Keys.onSpacePressed: mouse.clicked(null)
}
