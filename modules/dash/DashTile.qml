import QtQuick
import qs

// Kachel eines Dash-Eintrags: `.overview-icon` mit %tile (Radius 16, Padding 6) und flachem Button-Stil auf dem Dash-Hintergrund
// [_dash.scss:56-70, _drawing.scss:347-383]. Zustände kommen vom Eintrag, weil dessen Klickfläche größer ist als die Kachel
// (`&:hover .overview-icon`). Inhalt (Icon) liegt innerhalb des Paddings.
Item {
    id: root

    property real iconSize: Theme.dashIconSizeDefault
    property bool hovered: false
    property bool pressed: false
    // Menü offen oder Ziel eines Ablegens (:checked / :highlighted)
    property bool checked: false
    property bool focused: false

    readonly property string buttonState: Theme.buttonState(hovered, pressed, checked, enabled, focused)

    default property alias content: box.data

    implicitWidth: iconSize + 2 * Theme.tilePadding
    implicitHeight: iconSize + 2 * Theme.tilePadding

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusTile
        color: root.buttonState === "normal" ? "transparent" : Theme.buttonBg(root.buttonState, {
            "bg": Theme.dashBackground,
            "fg": Theme.systemFg,
            "style": "flat",
            "alwaysDark": true
        })

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationTile
                easing.type: Theme.easeTransition
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusTile
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRing
        opacity: root.focused ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    Item {
        id: box
        anchors.fill: parent
        anchors.margins: Theme.tilePadding
    }
}
