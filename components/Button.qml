import QtQuick
import qs

// Text-Button (.button / %button) [_buttons.scss:3-6, _common.scss:93-110]: fett, Padding 3 × 24, min. 22px hoch,
// Radius 8. `pill`: vollrund (z. B. .message-list-clear-button). `notification`: %notification_button
// [_common.scss:197-209], Padding 6 × 12 auf durchscheinendem Grund.
Item {
    id: root

    property string text: ""
    property bool pill: false
    property bool notification: false
    // suggested-action: Akzent-Hintergrund, weiße Schrift
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

    scale: pressed && enabled && !Theme.gameMode ? Theme.pressScale : 1
    Behavior on scale {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.durationPress
            easing.type: Theme.easeOut
        }
    }

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
