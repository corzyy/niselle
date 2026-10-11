import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Menü für Barrierefreiheit [GNOME-Mockup system-status-indicators]: Symbol in der Leiste, Klick öffnet ein Menü mit den
// Schaltern aus AccessibilityService. Sichtbar, wenn das Element in der Menüleisten-Anordnung (Einstellungen) steht.
Pill {
    id: root

    property color foreground: Theme.panelFg

    // Zeitpunkt, an dem das Menü zuletzt geschlossen wurde: der Klick, der per Fokus-Grab schloss, soll es nicht wieder öffnen
    property double closedAt: 0

    fg: foreground
    inset: Theme.panelButtonBorder
    checked: menu.open

    onClicked: m => {
        if (m && m.button !== Qt.LeftButton)
            return;
        if (!menu.open && Date.now() - root.closedAt < 200)
            return;
        menu.toggle();
    }

    Icon {
        name: "preferences-desktop-accessibility-symbolic"
        color: root.fg
        size: Theme.iconSize
    }

    PopupMenu {
        id: menu

        anchor.item: root
        anchor.rect.x: root.width / 2
        anchor.rect.y: root.height + Theme.popoverRise - margin - 1
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.None

        grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"
        onOpenChanged: if (!open)
            root.closedAt = Date.now()

        Repeater {
            model: AccessibilityService.options.filter(o => o.available)

            PopupMenuItem {
                required property var modelData
                text: modelData.title
                icon: modelData.icon
                ornamented: true
                ornamentChecked: SettingsService[modelData.key]
                closeOnActivate: false
                onActivated: SettingsService.set(modelData.key, !SettingsService[modelData.key])
            }
        }
    }
}
