import QtQuick
import qs

Item {
    id: root

    property real value: 0
    property real maximumValue: 1
    property real overdriveStart: maximumValue
    property real barHeight: Theme.osdLevelHeight
    property real separatorWidth: Theme.osdOverdriveSeparatorWidth
    property color troughColor: Theme.osdLevelBg
    property color fillColor: Theme.osdFg
    property color overdriveColor: Theme.destructive

    readonly property real _value: Math.max(0, Math.min(value, maximumValue))
    readonly property real barRadius: Math.min(width, barHeight) / 2
    readonly property real endX: maximumValue > 0 ? barRadius + (width - 2 * barRadius) * _value / maximumValue : 0
    readonly property real overdriveX: barRadius + (width - 2 * barRadius) * overdriveStart / maximumValue
    readonly property bool overdriveActive: overdriveStart !== maximumValue
    readonly property real _separator: overdriveActive ? separatorWidth : 0

    implicitWidth: Theme.osdLevelWidth
    implicitHeight: barHeight

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.barHeight
        radius: root.barRadius
        color: root.troughColor
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        height: root.barHeight
        width: Math.max(0, Math.min(root.endX, root.overdriveX - root._separator / 2))
        clip: true
        visible: root._value > 0

        Rectangle {
            width: parent.width + 2 * root.barRadius
            height: parent.height
            radius: root.barRadius
            color: root.fillColor
        }
    }

    Rectangle {
        readonly property real startX: Math.min(root.endX, root.overdriveX) + root._separator / 2
        visible: root.overdriveActive && root._value > root.overdriveStart
        anchors.verticalCenter: parent.verticalCenter
        x: startX
        width: Math.max(0, root.endX - startX)
        height: root.barHeight
        color: root.overdriveColor
    }

    Rectangle {
        visible: root.overdriveActive
        anchors.verticalCenter: parent.verticalCenter
        x: root.overdriveX - root._separator / 2
        width: root._separator
        height: root.barHeight
        color: root._value <= root.overdriveStart ? root.fillColor : root.troughColor
    }
}
