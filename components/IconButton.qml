import QtQuick
import qs

// .icon-button [_buttons.scss:18-38]: rund, 16px-Icon, Padding 12px.
// Stile: normal, flat (flat: true), default/Akzent (accent: true). Zustände über Theme.buttonBg().
Item {
    id: root

    property string icon: ""
    property bool flat: false
    property bool accent: false
    // %notification_button: durchscheinender Grund auf Karten
    property bool notification: false
    property bool checkable: false
    property bool checked: false
    property real padding: Theme.iconButtonPadding
    property real iconSize: Theme.iconSize
    // Bezugsfarben (Standard: Menü-/Fensterhintergrund)
    property color bg: Theme.bgColor
    property color fg: accent ? Theme.accentFg : Theme.fgColor

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property string buttonState: Theme.buttonState(hovered, pressed, checked, enabled, activeFocus)
    readonly property string style: notification ? "notification" : (accent ? "default" : (flat ? "flat" : ""))

    signal clicked

    implicitWidth: iconSize + 2 * padding
    implicitHeight: iconSize + 2 * padding
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
        radius: Theme.radiusPill
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.motionSnap
                easing.type: Theme.easeOut
            }
        }
        color: {
            const o = {
                "bg": root.accent ? Theme.accentColor : root.bg,
                "fg": root.fg,
                "style": root.style
            };
            if (root.flat && root.buttonState === "normal")
                return "transparent";
            return Theme.buttonBg(root.buttonState, o);
        }
    }

    // Fokusring: inset 0 0 0 2px, Übergang 300 ms [_drawing.scss:57-66, _common.scss:97]
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: root.accent ? Theme.focusRingDefault : Theme.focusRing
        opacity: root.activeFocus ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.enabled ? root.fg : Theme.buttonFgInsensitive(root.fg)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (root.checkable)
                root.checked = !root.checked;
            root.clicked();
        }
    }

    Keys.onReturnPressed: mouse.clicked(null)
    Keys.onSpacePressed: mouse.clicked(null)
}
