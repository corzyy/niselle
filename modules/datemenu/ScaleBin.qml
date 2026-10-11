import QtQuick
import qs

// Behälter mit ScaleLayout [messageList.js:159-224]: Der Inhalt skaliert um seine Mitte, die Höhe folgt der Skalierung.
// Erscheinen und Verschwinden dauern MESSAGE_ANIMATION_TIME (100 ms, EASE_OUT_QUAD). Nach dem Verkleinern auf 0 kommt
// `hidden`; der Besitzer entfernt den Eintrag dann.
Item {
    id: root

    // Soll sichtbar sein (false: verkleinern und entfernen)
    property bool shown: true
    // Beim Erzeugen aufblenden (sonst sofort voll da)
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
