import QtQuick
import qs

Item {
    id: root

    property bool shown: true
    property bool animateIn: true
    property real amount: animateIn ? 0 : 1
    property bool scalingEnabled: true
    readonly property real contentHeight: holder.height

    default property alias data: holder.data

    signal hidden

    width: parent ? parent.width : 0
    height: Math.round(holder.height * (scalingEnabled ? amount : (amount > 0 ? 1 : 0)))
    visible: amount > 0

    Component.onCompleted: amount = shown ? 1 : 0

    onShownChanged: amount = shown ? 1 : 0

    Behavior on amount {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.durationMessage
            easing.type: Theme.easeOutQuad
        }
    }

    onAmountChanged: if (!shown && amount === 0)
        hidden()

    Item {
        id: holder

        width: root.width
        height: childrenRect.height
        y: (root.height - height) / 2
        scale: root.scalingEnabled ? root.amount : 1
        transformOrigin: Item.Center
    }
}
