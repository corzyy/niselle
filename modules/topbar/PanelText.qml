import QtQuick
import qs

// Panel-Schrift: fett, tabellarische Ziffern [_panel.scss:15-17, %numeric _common.scss:287]
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
