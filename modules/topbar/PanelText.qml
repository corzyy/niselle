import QtQuick
import qs

Text {
    color: Theme.panelFg
    font.family: Theme.fontFamily
    font.pointSize: Theme.fontSizeBase
    font.weight: Theme.fontWeightBold
    font.features: ({
            "tnum": 1
        })
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        enabled: !Theme.gameMode
        ColorAnimation {
            duration: Theme.durationPanel
            easing.type: Theme.easeOutCubic
        }
    }
}
