import QtQuick
import qs

Rectangle {
    id: root

    property bool vertical: false
    property color lineColor: Theme.borders

    implicitWidth: vertical ? Theme.menuSeparatorHeight : 0
    implicitHeight: vertical ? 0 : Theme.menuSeparatorHeight
    color: lineColor
}
