import QtQuick
import qs

Item {
    id: root

    property string text: ""
    property bool pill: false
    property bool notification: false
    property bool primary: false
    property real radius: pill ? Theme.radiusPill : Theme.radiusButton
    property real paddingV: notification ? Theme.notificationButtonPaddingV : Theme.buttonPaddingV
    property real paddingH: notification ? Theme.notificationButtonPaddingH : Theme.buttonPaddingH
    property color fg: primary ? Theme.accentFg : Theme.fgColor

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property string buttonState: Theme.buttonState(hovered, pressed, false, enabled, activeFocus)

    signal clicked

    implicitWidth: label.implicitWidth + 2 * paddingH
    implicitHeight: Math.max(Theme.buttonMinHeight, label.implicitHeight) + 2 * paddingV
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.motionSnap
                easing.type: Theme.easeOut
            }
        }
        color: root.primary ? Theme.buttonBg(root.buttonState, {
            "bg": Theme.accentColor,
            "fg": Theme.accentFg,
            "style": "default"
        }) : Theme.buttonBg(root.buttonState, {
            "fg": root.fg,
            "style": root.notification ? "notification" : ""
        })
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: root.primary ? Theme.focusRingDefault : Theme.focusRing
        opacity: root.activeFocus ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 2 * root.paddingH)
        text: root.text
        elide: Text.ElideRight
        color: root.enabled ? root.fg : Theme.buttonFgInsensitive(root.fg)
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
