import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// ActionRow mit zusammenhängenden Segmenten (AdwToggleGroup): die gewählte Option liegt erhaben.
// `choices`: [{ value, label }]; `value` ist der gewählte Wert, `picked(value)` bei Auswahl.
ActionRow {
    id: root

    property var choices: []
    property var value

    signal picked(var value)

    Item {
        implicitWidth: segments.implicitWidth + 4
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusButton
            color: Theme.alpha(Theme.windowFg, 0.06)
            border.width: 1
            border.color: Theme.alpha(Theme.windowFg, 0.12)
            opacity: root.enabled ? 1 : Theme.disabledOpacity
        }

        Row {
            id: segments
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: root.choices

                Rectangle {
                    id: seg

                    required property var modelData
                    readonly property bool selected: modelData.value === root.value

                    implicitWidth: label.implicitWidth + 24
                    implicitHeight: 28
                    radius: Theme.radiusButton - 2
                    color: selected ? Theme.buttonBg("checked", {
                        "bg": Theme.alpha(Theme.windowFg, 0.06)
                    }) : (mouse.containsMouse ? Theme.alpha(Theme.windowFg, 0.08) : "transparent")

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        color: Theme.windowFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: seg.selected ? Theme.fontWeightBold : Theme.fontWeightNormal
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.enabled
                        onClicked: root.picked(seg.modelData.value)
                    }
                }
            }
        }
    }
}
