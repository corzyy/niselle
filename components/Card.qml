import QtQuick
import qs

// Karte (%card / %card_flat) [_common.scss:138-171]: Radius 12, Innenabstand 12, Außenabstand 4, 1px Rand in
// card_shadow_border_color, Schatten 0 1px 2px. `flat`: ohne Rand und Hintergrund, Hover wie ein flacher Button.
// Klickbar (`interactive`), Zustände über Theme.buttonBg(…, style card/flat). Die Fläche liegt um `margin` eingerückt,
// die implizite Größe enthält den Außenabstand wie die CSS-Box. Ein Kind, das `contentItem` füllt (anchors.fill).
Item {
    id: root

    property bool flat: false
    property bool interactive: true
    property real padding: Theme.cardPadding
    property real margin: Theme.cardMargin
    property real radius: Theme.radiusCard
    // Hintergrund ohne Interaktion überschreiben (z. B. Nachrichten)
    property var color: undefined
    // Rand und Schatten überschreiben (Nachrichtenstapel)
    property var borderColor: undefined
    property bool shadow: true
    property color shadowColor: Theme.cardShadowColor
    property real shadowBlur: Theme.shadowCardBlur
    property real shadowOffsetY: Theme.shadowCardY

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property string buttonState: interactive ? Theme.buttonState(hovered, pressed, false, true, activeFocus) : "normal"
    readonly property alias contentItem: content
    readonly property alias background: surface

    default property alias data: content.data

    signal clicked

    // Größe des Inhalts: implizite Größe des ersten Kinds (das Kind füllt `contentItem`)
    readonly property Item _child: content.children.length > 0 ? content.children[0] : null
    implicitWidth: (_child ? _child.implicitWidth : 0) + 2 * (padding + margin + Theme.cardBorderWidth)
    implicitHeight: (_child ? _child.implicitHeight : 0) + 2 * (padding + margin + Theme.cardBorderWidth)
    activeFocusOnTab: interactive

    ShadowRect {
        id: surface

        anchors.fill: parent
        anchors.margins: root.margin
        radius: root.radius
        color: {
            if (root.flat)
                return root.buttonState === "normal" || root.buttonState === "focus" ? "transparent" : Theme.buttonBg(root.buttonState, {
                    "style": "flat"
                });
            if (root.color !== undefined && root.buttonState === "normal")
                return root.color;
            return Theme.buttonBg(root.buttonState, {
                "style": "card"
            });
        }
        border.width: Theme.cardBorderWidth
        border.color: root.flat ? "transparent" : (root.borderColor !== undefined ? root.borderColor : Theme.cardShadowBorder)
        shadowColor: root.flat || !root.shadow ? "transparent" : root.shadowColor
        shadowBlur: root.shadowBlur
        shadowOffsetY: root.shadowOffsetY
        highlight: !root.flat

        // Stapelstufe/Hover wechseln weich (z. B. Karten beim Auf-/Zuklappen einer Benachrichtigungsgruppe)
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationGroupExpand
                easing.type: Theme.easeOut
            }
        }
        Behavior on border.color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationGroupExpand
                easing.type: Theme.easeOut
            }
        }
        Behavior on shadowColor {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationGroupExpand
                easing.type: Theme.easeOut
            }
        }

        // Fokusring [_drawing.scss:57-66]
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.width: Theme.focusRingWidth
            border.color: Theme.focusRing
            opacity: root.activeFocus ? 1 : 0

            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.durationButton
                    easing.type: Theme.easeTransition
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: surface
        enabled: root.interactive
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Item {
        id: content
        anchors.fill: surface
        anchors.margins: root.padding + Theme.cardBorderWidth
    }

    Keys.onReturnPressed: if (interactive)
        root.clicked()
    Keys.onSpacePressed: if (interactive)
        root.clicked()
}
