import QtQuick
import qs

Item {
    id: root

    property bool running: false
    property color color: Theme.fgColor
    property real size: Theme.iconSize
    property bool hideOnStop: true

    implicitWidth: size
    implicitHeight: size
    visible: running || !hideOnStop

    Icon {
        id: icon
        anchors.fill: parent
        name: "content-loading-symbolic"
        color: root.color
        size: root.size

        RotationAnimator on rotation {
            running: root.running && root.visible
            from: 0
            to: 360
            duration: Theme.durationSpinner
            loops: Animation.Infinite
        }
    }
}
