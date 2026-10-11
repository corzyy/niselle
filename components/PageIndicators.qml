import QtQuick
import qs

// Seitenpunkte des App-Grids [pageIndicators.js, _app-grid.scss:120-132]: ein Punkt je Seite, der aktuelle voll, die übrigen
// auf 2/3 verkleinert und halb transparent (Zeiger darüber: voll sichtbar, gedrückt: auf 1/2). Zwischen zwei Seiten
// (Wischen) blendet `currentPosition` stufenlos über. Erst ab zwei Seiten sichtbar.
Item {
    id: root

    property int nPages: 0
    // Seite als Kommazahl, z. B. 1.5 mitten im Wechsel von Seite 1 zu 2
    property real currentPosition: 0

    signal pageActivated(int page)

    visible: nPages > 1
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.pageIndicatorPaddingTop + Theme.pageIndicatorSize

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        Repeater {
            model: root.nPages

            Item {
                id: indicator

                required property int index
                // Nähe zur aktuellen Position: 1 auf der Seite, 0 ab einer Seite Abstand
                readonly property real progress: Math.max(1 - Math.abs(root.currentPosition - index), 0)
                readonly property real inactiveScale: mouse.pressed ? Theme.pageIndicatorInactiveScalePressed : Theme.pageIndicatorInactiveScale
                readonly property real inactiveOpacity: mouse.containsMouse ? Theme.pageIndicatorInactiveOpacityHover : Theme.pageIndicatorInactiveOpacity

                width: Theme.pageIndicatorSize + 2 * Theme.pageIndicatorPaddingH
                height: Theme.pageIndicatorPaddingTop + Theme.pageIndicatorSize

                Rectangle {
                    x: Theme.pageIndicatorPaddingH
                    y: Theme.pageIndicatorPaddingTop
                    width: Theme.pageIndicatorSize
                    height: Theme.pageIndicatorSize
                    radius: Theme.radiusPill
                    color: Theme.systemFg
                    scale: indicator.inactiveScale + (1 - indicator.inactiveScale) * indicator.progress
                    opacity: indicator.inactiveOpacity + (1 - indicator.inactiveOpacity) * indicator.progress
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: root.pageActivated(indicator.index)
                }
            }
        }
    }
}
