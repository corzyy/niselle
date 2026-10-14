import QtQuick
import QtQuick.Layouts
import qs
import qs.components

ActionRow {
    id: root

    property int value: 0
    property int from: 0
    property int to: 99

    signal picked(int value)

    Button {
        text: "−"
        enabled: root.value > root.from
        onClicked: root.picked(root.value - 1)
    }
    Text {
        Layout.minimumWidth: 24
        horizontalAlignment: Text.AlignHCenter
        text: root.value
        color: Theme.windowFg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
        font.features: ({
                "tnum": 1
            })
    }
    Button {
        text: "+"
        enabled: root.value < root.to
        onClicked: root.picked(root.value + 1)
    }
}
