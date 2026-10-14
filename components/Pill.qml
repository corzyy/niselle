import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property color fg: Theme.panelFg
    property var filledColor: undefined
    property bool checked: false
    property bool interactive: true
    property real inset: 0
    property real hPadding: Theme.panelButtonHPadding
    property real spacing: Theme.panelIndicatorSpacing

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property string fillState: {
        const active = pressed || checked;
        if (active)
            return hovered ? "activeHover" : "active";
        return (hovered || activeFocus) ? "hover" : "normal";
    }

    default property alias content: row.data

    signal clicked(var mouse)
    signal wheeled(real angleDeltaX, real angleDeltaY, real x, real y)

    implicitWidth: row.implicitWidth + 2 * (hPadding + inset)
    implicitHeight: row.implicitHeight + 2 * inset
    activeFocusOnTab: interactive

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.inset
        radius: Theme.radiusPill
        color: root.interactive ? Theme.panelButtonFill(root.fillState, root.fg, root.filledColor) : (root.filledColor ?? "transparent")

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationPanelButton
                easing.type: Theme.easeTransition
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheeled(w.angleDelta.x, w.angleDelta.y, w.x, w.y)
    }

    Keys.onReturnPressed: root.clicked(null)
    Keys.onSpacePressed: root.clicked(null)
}
