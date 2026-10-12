import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// AdwActionRow (55px bei zwei Zeilen, 50px bei einer). `property`: Stil .property – kleine Beschriftung oben, Wert unten
// (title = Beschriftung, subtitle = Wert). Trailing-Widgets als Kinder (Schalter, Knöpfe).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    // .property-Stil: Titel klein/gedämpft über dem Wert
    property bool propertyStyle: false
    property string icon: ""
    // Nummern-Kennzeichen vor dem Titel (Anzeigen-Nummer, .monitor-label)
    property string badge: ""
    // false: Icon unverändert darstellen (App-Icons)
    property bool iconSymbolic: true
    property bool activatable: false
    // Pfeil „>“ bzw. Symbol am Ende (z. B. "adw-external-link-symbolic")
    property string suffixIcon: ""
    // Schmale Zeile für reine Navigationslisten (einzeilig, 40px)
    property bool dense: false

    default property alias trailing: trailingRow.data

    readonly property bool hovered: mouse.containsMouse
    signal activated

    Layout.fillWidth: true
    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(dense ? 40 : Theme.compact ? 48 : 60, textColumn.implicitHeight + 2 * (dense ? 4 : Theme.compact ? 6 : 10) + (textColumn.visibleChildren.length > 1 ? 6 : 0))

    // Trennlinie zur vorigen Zeile
    Rectangle {
        visible: root.y > 0
        anchors.top: parent.top
        x: 16
        width: parent.width - 32
        height: 1
        color: Theme.alpha(Theme.windowFg, Theme.dark ? 0.06 : 0.08)
    }

    Rectangle {
        anchors.fill: parent
        color: root.activatable ? (mouse.pressed ? Theme.alpha(Theme.windowFg, 0.14) : (root.hovered ? Theme.alpha(Theme.windowFg, 0.07) : Theme.alpha(Theme.windowFg, 0))) : Theme.alpha(Theme.windowFg, 0)

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationTile
                easing.type: Theme.easeTransition
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 14

        Icon {
            visible: root.icon !== ""
            name: root.icon
            symbolic: root.iconSymbolic
            color: Theme.windowFg
        }

        // Nummern-Kennzeichen (.monitor-label): Kreis mit Zahl
        Rectangle {
            visible: root.badge !== ""
            Layout.alignment: Qt.AlignVCenter
            width: 24
            height: 24
            radius: 12
            color: "#dddddd"

            Text {
                anchors.centerIn: parent
                text: root.badge
                color: "#000000"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
                font.features: ({ "tnum": 1 })
            }
        }

        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                visible: text !== ""
                color: root.propertyStyle ? Theme.alpha(Theme.windowFg, 0.55) : Theme.windowFg
                font.family: Theme.fontFamily
                font.pointSize: root.propertyStyle ? Theme.fontSizeCaption : Theme.fontSizeBase
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                elide: Text.ElideRight
                visible: text !== ""
                color: root.propertyStyle ? Theme.windowFg : Theme.alpha(Theme.windowFg, 0.55)
                font.family: Theme.fontFamily
                font.pointSize: root.propertyStyle ? Theme.fontSizeBase : Theme.fontSizeCaption
            }
        }

        RowLayout {
            id: trailingRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
        }

        Icon {
            visible: root.suffixIcon !== ""
            name: root.suffixIcon
            color: Theme.alpha(Theme.windowFg, root.activatable && root.hovered ? 0.9 : 0.55)
            transform: Translate {
                x: root.activatable && root.hovered ? 2 : 0

                Behavior on x {
                    enabled: !Theme.gameMode
                    NumberAnimation {
                        duration: Theme.durationMenuItem
                        easing.type: Theme.easeOutCubic
                    }
                }
            }

            Behavior on color {
                enabled: !Theme.gameMode
                ColorAnimation {
                    duration: Theme.durationTile
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        // unter den Trailing-Widgets, damit deren Knöpfe Klicks bekommen
        z: -1
        enabled: root.activatable
        hoverEnabled: true
        onClicked: root.activated()
    }
}
