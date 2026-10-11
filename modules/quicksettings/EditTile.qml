import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Kachel im Bearbeitungsmodus der Quick-Settings: Pille wie ToggleButton (nur Icon und Titel) mit rundem
// Plus-/Minus-Abzeichen an der oberen rechten Ecke. `dimmed`: Kachel ist bereits in der Leiste (blass, ohne Abzeichen).
Item {
    id: root

    property string title: ""
    property string icon: ""
    // false: Icon unverändert (farbig) darstellen, z. B. die israelische Flagge der BigYahoo-Kachel
    property bool symbolic: true
    // "remove" (Minus), "add" (Plus) oder "" (kein Abzeichen)
    property string badge: ""
    property bool dimmed: false
    property bool dragging: false
    // Ziehbar: die Maus bleibt beim Ziehen bei der Kachel, die Flickable-Liste scrollt dann nicht mit
    property bool draggable: false

    property alias mouse: area

    signal badgeClicked
    signal clicked

    implicitWidth: Theme.quickToggleWidth
    implicitHeight: Theme.quickToggleHeight
    opacity: dimmed ? 0.35 : 1

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: Theme.buttonBg(root.dimmed ? "normal" : Theme.buttonState(area.containsMouse, area.pressed, false, true, false), {})
        scale: root.dragging ? 1.04 : 1

        Behavior on scale {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton / 2
                easing.type: Theme.easeOutQuad
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.quickToggleIconLeading
        anchors.rightMargin: Theme.quickToggleHPadding
        spacing: Theme.quickToggleSpacing

        Icon {
            name: root.icon
            symbolic: root.symbolic
            visible: root.icon !== ""
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.fgColor
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeHeading
            font.weight: Theme.fontWeightBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.dimmed
        preventStealing: root.draggable
        onClicked: root.clicked()
    }

    // Abzeichen: dunkler Kreis mit Rand, ragt über die Ecke der Pille
    Rectangle {
        id: badgeDot

        visible: root.badge !== "" && !root.dimmed
        width: 22
        height: 22
        radius: width / 2
        x: root.width - width + 2
        y: -4
        color: Theme.baseColor
        border.width: 1
        border.color: Theme.outerBorders
        opacity: root.dragging ? 0 : 1

        Icon {
            anchors.centerIn: parent
            size: 12
            name: root.badge === "add" ? "list-add-symbolic" : "list-remove-symbolic"
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: root.badgeClicked()
        }
    }
}
