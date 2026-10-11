import QtQuick
import qs
import qs.services
import qs.components

// Aktives Tastaturlayout (Kurzname wie "de"), nur bei mehreren konfigurierten Layouts sichtbar
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
