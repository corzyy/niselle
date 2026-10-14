import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property string text: ""

    Layout.fillWidth: true
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + 2 * Theme.menuItemPaddingV

    Text {
        id: label

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.menuItemPaddingH
        anchors.rightMargin: Theme.menuItemPaddingH
        text: root.text
        color: Theme.transparentize(Theme.fgColor, 0.45)
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeCaptionHeading
        font.weight: Theme.fontWeightBold
    }
}
