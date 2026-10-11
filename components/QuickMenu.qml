import QtQuick
import QtQuick.Layouts
import qs

// Untermenü der Quick-Settings (.quick-toggle-menu, QuickToggleMenu) [quickSettings.js:371-502, _quick-settings.scss:150-203].
// Karte mit Kopf (Icon-Kreis, Titel, Untertitel) und Einträgen. Die Höhe des Platzhalters im Layout wächst zuerst
// (200 ms, EASE_OUT_QUAD), danach blendet die Karte ein (200 ms); Schließen läuft umgekehrt. Die Karte selbst
// bleibt bis zum Einblenden unsichtbar, sie wächst nicht sichtbar mit.
//
// `height` ist die belegte Höhe im Layout (0 = zu); die Karte liegt oben bündig und hat ihre natürliche Höhe.
// Einträge (PopupMenuItem) schließen beim Aktivieren dieses Untermenü, nicht das ganze Popup.
Item {
    id: root

    property bool open: false
    property string headerIcon: ""
    property string headerTitle: ""
    property string headerSubtitle: ""
    // Kopf-Icon in Akzentfarbe, wenn die zugehörige Kachel an ist (.active)
    property bool headerActive: false

    // Einträge unter dem Kopf
    default property alias content: column.data
    // Elemente rechts im Kopf (z. B. Ladekreis)
    property alias headerSuffix: suffix.data

    // Anteil der geöffneten Höhe (0..1) und Deckkraft der Karte
    property real reveal: 0
    property real fade: 0

    readonly property bool shown: reveal > 0 || open || fade > 0
    readonly property real naturalHeight: card.implicitHeight

    signal closed
    // Schließwunsch (PopupMenuItem): der Besitzer setzt `open` über seine Bindung zurück
    signal closeRequested

    // Wird von PopupMenuItem in der Elternkette gesucht
    readonly property var menuOwner: root

    function close() {
        closeRequested();
    }

    visible: shown
    height: reveal * naturalHeight

    onOpenChanged: {
        // Gamemode: Höhe und Deckkraft sofort setzen, ohne Animation
        if (Theme.gameMode) {
            openAnimation.stop();
            closeAnimation.stop();
            reveal = open ? 1 : 0;
            fade = open ? 1 : 0;
            if (!open)
                closed();
            return;
        }
        if (open) {
            closeAnimation.stop();
            openAnimation.restart();
        } else {
            openAnimation.stop();
            closeAnimation.restart();
        }
    }

    // Öffnen: erst Höhe (Dauer anteilig zur Strecke), dann Deckkraft [quickSettings.js:400-428]
    SequentialAnimation {
        id: openAnimation

        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: Theme.durationQuickMenu * (1 - root.reveal)
            easing.type: Theme.easeOutQuad
        }
        NumberAnimation {
            target: root
            property: "fade"
            to: 1
            duration: Theme.durationQuickMenu * (1 - root.fade)
            easing.type: Theme.easeOutQuad
        }
    }

    // Schließen: erst ausblenden (Dauer anteilig zur Deckkraft), dann Höhe einfahren [quickSettings.js:437-461]
    SequentialAnimation {
        id: closeAnimation

        NumberAnimation {
            target: root
            property: "fade"
            to: 0
            duration: Theme.durationQuickMenu * root.fade
            easing.type: Theme.easeOutQuad
        }
        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: Theme.durationQuickMenu * root.reveal
            easing.type: Theme.easeOutQuad
        }
        ScriptAction {
            script: root.closed()
        }
    }

    ShadowRect {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        y: 0
        implicitHeight: layout.implicitHeight + 2 * (Theme.cardPadding + Theme.cardBorderWidth)
        height: implicitHeight
        opacity: root.fade

        color: Theme.glass(Theme.buttonBg("normal", {
            "style": "card"
        }))
        radius: Theme.radiusQuickToggleMenu
        border.width: Theme.cardBorderWidth
        border.color: Theme.cardShadowBorder
        shadowColor: Theme.cardShadowColor
        shadowBlur: Theme.shadowCardBlur
        shadowOffsetY: Theme.shadowCardY
        padding: Theme.cardPadding + Theme.cardBorderWidth

        ColumnLayout {
            id: layout
            anchors.fill: parent
            spacing: 0

            // Kopf [_quick-settings.scss:163-203]
            RowLayout {
                visible: root.headerTitle !== ""
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.quickMenuHeaderPaddingBottom
                spacing: Theme.quickMenuHeaderSpacingH

                Rectangle {
                    implicitWidth: Theme.iconSizeMedium + 2 * Theme.quickMenuHeaderIconPadding
                    implicitHeight: implicitWidth
                    radius: Theme.radiusPill
                    color: root.headerActive ? Theme.accentColor : Theme.quickMenuHeaderIconBg

                    Icon {
                        anchors.centerIn: parent
                        name: root.headerIcon
                        size: Theme.iconSizeMedium
                        color: root.headerActive ? Theme.accentFg : Theme.fgColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.quickMenuHeaderSpacingV

                    Text {
                        Layout.fillWidth: true
                        text: root.headerTitle
                        color: Theme.fgColor
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeTitle3
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.headerSubtitle !== ""
                        text: root.headerSubtitle
                        color: Theme.fgColor
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaptionHeading
                        font.weight: Theme.fontWeightBold
                    }
                }

                RowLayout {
                    id: suffix
                    spacing: 0
                }
            }

            ColumnLayout {
                id: column
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }
}
