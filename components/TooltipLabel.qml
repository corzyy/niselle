import QtQuick
import qs

// Tooltip (%tooltip) [_common.scss:225-232, _dash.scss:103-106]: fast schwarze Pille mit hellem Rand, zentrierter Text
Rectangle {
    id: root

    property alias text: label.text

    readonly property real frame: Theme.tooltipPaddingH + Theme.tooltipBorderWidth

    implicitWidth: label.implicitWidth + 2 * frame
    implicitHeight: label.implicitHeight + 2 * (Theme.tooltipPaddingV + Theme.tooltipBorderWidth)
    radius: Theme.radiusPill
    color: Theme.tooltipBg
    border.width: Theme.tooltipBorderWidth
    border.color: Theme.tooltipBorder

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.tooltipFg
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }
}
