import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Popover-Menü (.popup-menu-boxpointer + .popup-menu-content) [_popovers.scss:11-33].
// Karte: bg_color, radius 20, 1px outer_borders, Schatten 0 2px 4px, Padding 6, min. Breite 15em.
// Öffnen/Schließen wie BoxPointer [boxpointer.js:74-185]: 150 ms EASE_OUT_QUAD, Deckkraft 0↔1,
// Skalierung 0.96↔1 um den Pfeilrand, Verschiebung um -arrow-rise (6px) zum Pfeilrand hin.
//
// Das Fenster ist rundum um `margin` größer als die Karte (Platz für den Schatten). Anker (anchor.item,
// anchor.edges, anchor.gravity, anchor.rect) bezieht sich auf das Fenster, die Karte beginnt bei (margin, margin).
PopupWindow {
    id: root

    // Gewünschter Zustand; Schließen animiert und blendet das Fenster danach aus
    property bool open: false
    // Seite der Karte, an der das Menü hängt (Qt.TopEdge: Menü unter dem Panel)
    property int arrowSide: Qt.TopEdge
    property real minWidth: Theme.popoverMinWidth
    // Dauer von Öffnen/Schließen (Quick-Settings nehmen länger für das gestaffelte Einblenden)
    property int openDuration: Theme.durationPopover
    // Quick-Settings überschreiben Radius und Innenabstand [_quick-settings.scss:1-4]
    property real cornerRadius: Theme.radiusPopover
    property real contentPadding: Theme.popoverPadding
    readonly property real margin: Math.ceil(Theme.shadowPopoverBlur + Theme.shadowPopoverY + 2)
    // Mindesthöhe der Karte im Fenster: Fenstergröße bleibt während Animationen der Karte konstant
    property real reserveHeight: 0
    readonly property real progress: openAnimation.progress

    default property alias content: column.data

    function show() { open = true; }
    function close() { open = false; }
    function toggle() { open = !open; }

    color: "transparent"
    grabFocus: true
    implicitWidth: card.width + 2 * margin
    implicitHeight: Math.max(card.height, reserveHeight) + 2 * margin

    onOpenChanged: {
        if (open)
            visible = true;
        openAnimation.progress = open ? 1 : 0;
    }

    // Klick daneben (Fokus-Grab) blendet das Fenster aus: Zustand nachziehen
    onVisibleChanged: {
        if (!visible && open) {
            openAnimation.progress = 0;
            open = false;
        }
    }

    Item {
        id: openAnimation
        property real progress: 0

        Behavior on progress {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: root.openDuration
                easing.type: Theme.easeOutQuad
                onRunningChanged: {
                    if (!running && !root.open)
                        root.visible = false;
                }
            }
        }
    }

    ShadowRect {
        id: card

        x: root.margin
        y: root.margin
        width: Math.max(root.minWidth, column.implicitWidth + 2 * (root.contentPadding + Theme.popoverBorderWidth))
        height: column.implicitHeight + 2 * (root.contentPadding + Theme.popoverBorderWidth)

        color: Theme.menuBg
        radius: root.cornerRadius
        border.width: Theme.popoverBorderWidth
        border.color: Theme.outerBorders
        shadowColor: Theme.shadowColor
        shadowBlur: Theme.shadowPopoverBlur
        shadowOffsetY: Theme.shadowPopoverY
        highlight: true
        padding: root.contentPadding + Theme.popoverBorderWidth

        opacity: root.progress
        transform: [
            Scale {
                readonly property bool vertical: root.arrowSide === Qt.TopEdge || root.arrowSide === Qt.BottomEdge
                origin.x: root.arrowSide === Qt.LeftEdge ? 0 : (root.arrowSide === Qt.RightEdge ? card.width : card.width / 2)
                origin.y: root.arrowSide === Qt.TopEdge ? 0 : (root.arrowSide === Qt.BottomEdge ? card.height : card.height / 2)
                xScale: Theme.popoverScaleFrom + (1 - Theme.popoverScaleFrom) * root.progress
                yScale: xScale
            },
            Translate {
                readonly property real rise: Theme.popoverRise * (1 - root.progress)
                x: root.arrowSide === Qt.LeftEdge ? -rise : (root.arrowSide === Qt.RightEdge ? rise : 0)
                y: root.arrowSide === Qt.TopEdge ? -rise : (root.arrowSide === Qt.BottomEdge ? rise : 0)
            }
        ]

        ColumnLayout {
            id: column

            // Marker, den PopupMenuItem in der Elternkette sucht
            readonly property var menuOwner: root

            anchors.fill: parent
            spacing: 0
            focus: true
            Keys.onEscapePressed: root.close()
        }
    }
}
