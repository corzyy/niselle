import QtQuick
import qs
import qs.services
import qs.components

Pill {
    id: root

    property color foreground: Theme.panelFg

    fg: foreground
    inset: Theme.panelButtonBorder
    interactive: false
    visible: KeyboardService.multiple

    PanelText {
        text: KeyboardService.shortName
        color: root.fg
    }
}
