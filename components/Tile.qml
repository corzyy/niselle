import QtQuick
import QtQuick.Layouts
import qs

// Icon-Kachel (Dash-, App-Grid-, Workspace-Elemente) [_drawing.scss:347-383, tile_button(); _common.scss:84-90, %tile]:
// radius 16, padding 6, spacing 6, Übergang 100 ms. Standard: System-Farben (immer dunkel), flach.
Item {
    id: root

    property color fg: Theme.systemFg
    property color bg: Theme.systemBg
    property bool system: true
    // raised: dauerhaft gefüllter Hintergrund statt flach
    property bool raised: false
    // checked/selected/highlighted
    property bool checked: false
    property real padding: Theme.tilePadding
    property real spacing: Theme.tileSpacing
    property real radius: Theme.radiusTile
    property bool interactive: true
    // Ziel eines Ablegens (:drop)
    property bool dropTarget: false

    // Zustände kommen standardmäßig aus der eigenen Maus; Kacheln mit eigener Mausfläche überschreiben sie
    property bool hovered: mouse.containsMouse
    property bool pressed: mouse.pressed
    // Tastaturfokus (Fokusring)
    property bool focused: activeFocus
    readonly property string buttonState: Theme.buttonState(hovered, pressed, checked, enabled, focused)

    default property alias content: column.data

    signal clicked(var mouse)

    implicitWidth: column.implicitWidth + 2 * padding
    implicitHeight: column.implicitHeight + 2 * padding
    activeFocusOnTab: interactive

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: {
            if (root.dropTarget)
                return Theme.tileDropBg;
            if (!root.raised && root.buttonState === "normal")
                return "transparent";
            return Theme.glass(Theme.buttonBg(root.buttonState, {
                "bg": root.bg,
                "fg": root.fg,
                "style": root.raised ? "" : "flat",
                "alwaysDark": root.system
            }));
        }

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
        radius: root.radius
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: root.dropTarget ? Theme.tileDropRing : Theme.focusRing
        opacity: root.focused || root.dropTarget ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.spacing
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
    }

    Keys.onReturnPressed: root.clicked(null)
    Keys.onSpacePressed: root.clicked(null)
}
