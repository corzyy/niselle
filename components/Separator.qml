import QtQuick
import qs

// 1px-Trennlinie [_popovers.scss:114-120]: background-color borders_color, height 1px
Rectangle {
    id: root

    property bool vertical: false
    property color lineColor: Theme.borders

    implicitWidth: vertical ? Theme.menuSeparatorHeight : 0
    implicitHeight: vertical ? 0 : Theme.menuSeparatorHeight
    color: lineColor
}
