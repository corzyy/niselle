import QtQuick
import QtQuick.Layouts
import qs

// AdwPreferencesGroup: optionale Überschrift (heading) und eine Karte (.boxed-list) mit Zeilen.
// Die Zeilen sind direkte Kinder; ActionRow zeichnet die Trennlinie selbst.
ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    // false: Inhalt ohne Karte (eigene Flächen, z. B. der Leisten-Editor)
    property bool boxed: true

    default property alias rows: list.data

    Layout.fillWidth: true
    spacing: 8

    Text {
        Layout.fillWidth: true
        visible: root.title !== ""
        Layout.leftMargin: 4
        text: root.title
        color: Theme.alpha(Theme.windowFg, 0.6)
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    Text {
        Layout.fillWidth: true
        visible: root.description !== ""
        text: root.description
        Layout.leftMargin: 4
        Layout.bottomMargin: 2
        wrapMode: Text.Wrap
        color: Theme.alpha(Theme.windowFg, 0.55)
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: list.implicitHeight
        radius: Theme.radiusCard * 1.25
        color: root.boxed ? Theme.cardBg : "transparent"
        clip: root.boxed

        Column {
            id: list
            width: parent.width
        }

        // 1px-Innenrand wie .card/.boxed-list (box-shadow 0 0 0 1px cardShade)
        Rectangle {
            visible: root.boxed
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.dark ? Theme.alpha(Theme.windowFg, 0.05) : Theme.alpha(Theme.windowFg, 0.07)
        }
    }
}
