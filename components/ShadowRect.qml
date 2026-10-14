import QtQuick
import QtQuick.Effects
import qs

Item {
    id: root

    property color color: "transparent"
    property real radius: 0
    property alias border: body.border
    property real padding: 0
    property bool highlight: false

    property color shadowColor: Theme.shadowColor
    property real shadowBlur: 0
    property real shadowOffsetX: 0
    property real shadowOffsetY: 0

    default property alias data: content.data
    readonly property alias contentItem: content

    readonly property bool hasShadow: !Theme.gameMode && shadowBlur > 0 && shadowColor.a > 0

    Rectangle {
        id: body
        anchors.fill: parent
        color: root.color
        radius: root.radius
        visible: !root.hasShadow
    }

    MultiEffect {
        anchors.fill: body
        source: body
        visible: root.hasShadow
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: root.shadowColor
        blurMax: 64
        shadowBlur: Math.min(1, root.shadowBlur / blurMax)
        shadowHorizontalOffset: root.shadowOffsetX
        shadowVerticalOffset: root.shadowOffsetY
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
