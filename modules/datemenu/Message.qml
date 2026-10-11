import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

// Nachricht (.message) [messageList.js Message, _message-list.scss:86-215]: Karte mit Kopf (Quellsymbol, Name, Zeit,
// Aufklappen, Schließen), Inhalt (Symbol 48px, Titel fett, Text) und Aktionsleiste. Der Text steht eingeklappt in einer
// Zeile und klappt auf bis zu 6 Zeilen auf, Aktionen erscheinen erst aufgeklappt (200 ms EASE_OUT_QUAD, Pfeil dreht um
// 180°). `stackLevel` färbt die Karte im Stapel (0 oben, 1 zweite, 2 tiefer).
Card {
    id: root

    property string sourceTitle: ""
    property string sourceIcon: ""
    property string title: ""
    property string body: ""
    property string timeText: ""
    // Symbol der Nachricht: Bild-URL, Pfad oder Symbolname; leer: kein Symbol
    property string iconSource: ""
    // Albumcover (Medienkarte): abgerundetes Bild bzw. Notensymbol
    property bool media: false
    property bool closable: true
    // Banner: Aufklapp-Knopf ausgeblendet, Schließen-Knopf nur bei Hover
    property bool expandable: true
    property real closeOpacity: 1
    // [{ label, trigger: function }], höchstens 3 sichtbar [messageList.js MAX_NOTIFICATION_BUTTONS]
    property var actions: []
    property int stackLevel: 0
    property bool expanded: false
    // Fokus-Tastenkürzel: Entf/Rücktaste schließen
    property alias controls: controlsRow.data

    property real expansion: expanded ? 1 : 0
    readonly property bool canExpand: expanded || actions.length > 0 || measure.lineCount > 1

    signal closeRequested
    // Der Nutzer klappt auf/zu; die Gruppe reagiert (eine eingeklappte Gruppe klappt selbst auf)
    signal expandRequested(bool expand)

    function toggleExpanded() {
        root.expandRequested(!root.expanded);
    }

    margin: 0
    padding: Theme.messagePadding
    radius: Theme.radiusMessage
    color: stackLevel === 0 ? Theme.messageBg : (stackLevel === 1 ? Theme.messageSecondBg : Theme.messageLowerBg)
    borderColor: stackLevel >= 2 ? Theme.messageLowerBorder : undefined
    shadow: stackLevel === 0

    Behavior on expansion {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.durationMessageExpand
            easing.type: Theme.easeOutQuad
        }
    }

    Keys.onDeletePressed: if (root.closable)
        root.closeRequested()
    Keys.onBackPressed: if (root.closable)
        root.closeRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ───────── Kopf ─────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.messageHeaderButtonPadding
            spacing: Theme.messageHeaderSpacing

            Icon {
                id: sourceIcon
                Layout.alignment: Qt.AlignVCenter
                size: Theme.iconSize
                symbolic: false
                name: root.sourceIcon !== "" && (root.sourceIcon.startsWith("/") || Quickshell.iconPath(root.sourceIcon, true) !== "") ? root.sourceIcon : "application-x-executable-symbolic"
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: -1
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Math.max(Theme.messageHeaderMinHeight, sourceLabel.implicitHeight) + Theme.messageHeaderSpacing

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.messageHeaderSpacing
                    spacing: Theme.messageHeaderSpacing

                    Text {
                        id: sourceLabel
                        Layout.alignment: Qt.AlignBottom
                        Layout.maximumWidth: parent.width
                        text: root.sourceTitle !== "" ? root.sourceTitle : "Unbekannte App"
                        elide: Text.ElideRight
                        color: Theme.cardInsensitiveFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 1
                        visible: root.timeText !== ""
                        text: root.timeText
                        elide: Text.ElideRight
                        color: Theme.cardInsensitiveFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightNormal
                    }
                    Item {
                        Layout.fillWidth: true
                        visible: root.timeText === ""
                    }
                }
            }

            IconButton {
                id: expandButton
                icon: Quickshell.shellPath("assets/icons/notification-expand-symbolic.svg")
                notification: true
                padding: Theme.messageHeaderButtonPadding
                visible: root.expandable
                opacity: root.canExpand ? 1 : 0
                enabled: root.canExpand
                rotation: 180 * root.expansion
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggleExpanded()
            }
            Item {
                visible: root.closable
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: closeButton.implicitWidth + 2 * Theme.messageCloseButtonMargin
                implicitHeight: closeButton.implicitHeight + 2 * Theme.messageCloseButtonMargin

                IconButton {
                    id: closeButton
                    anchors.centerIn: parent
                    icon: "window-close-symbolic"
                    notification: true
                    opacity: root.closeOpacity
                    enabled: root.closeOpacity > 0
                    padding: Theme.messageHeaderButtonPadding
                    onClicked: root.closeRequested()
                }
            }
        }

        // ───────── Inhalt ─────────
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.messagePadding
            Layout.topMargin: 0
            spacing: 0

            // Symbol: 48px; symbolische Symbole auf einem Kreis, Cover mit Radius 8
            Item {
                id: iconBox

                readonly property bool symbolicIcon: root.iconSource.endsWith("-symbolic")
                readonly property bool isCover: root.media && root.iconSource !== "" && !symbolicIcon
                readonly property bool themed: root.iconSource === "" ? root.media : symbolicIcon

                Layout.alignment: Qt.AlignTop
                Layout.rightMargin: Theme.messageIconMargin
                visible: root.iconSource !== "" || root.media
                implicitWidth: Theme.messageIconSize
                implicitHeight: Theme.messageIconSize

                Rectangle {
                    anchors.fill: parent
                    visible: iconBox.themed
                    radius: root.media ? Theme.radiusMediaArt : Theme.radiusPill
                    color: Theme.messageThemedIconBg
                }
                Icon {
                    anchors.centerIn: parent
                    visible: iconBox.themed
                    size: root.media ? Theme.mediaThemedIconSize : Theme.iconSize
                    name: root.iconSource !== "" ? root.iconSource : "audio-x-generic-symbolic"
                    color: Theme.fgColor
                }
                ClippingRectangle {
                    anchors.fill: parent
                    visible: iconBox.isCover
                    radius: Theme.radiusMediaArt
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: iconBox.isCover ? root.iconSource : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Image {
                    anchors.fill: parent
                    visible: !iconBox.themed && !iconBox.isCover && root.iconSource !== ""
                    source: visible && (root.iconSource.includes("://") || root.iconSource.startsWith("/")) ? (root.iconSource.startsWith("/") ? "file://" + root.iconSource : root.iconSource) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(Theme.messageIconSize, Theme.messageIconSize)
                }
                Icon {
                    anchors.fill: parent
                    visible: !iconBox.themed && !iconBox.isCover && root.iconSource !== "" && !root.iconSource.includes("://") && !root.iconSource.startsWith("/")
                    symbolic: false
                    size: Theme.messageIconSize
                    name: visible ? root.iconSource : ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.messageContentSpacing

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.title.replace(/\n/g, " ")
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }

                // Text: eine Zeile, aufgeklappt bis zu 6 [LabelExpanderLayout]
                Item {
                    id: bodyBin

                    readonly property real lineHeight: measureLine.implicitHeight
                    readonly property real fullHeight: Math.min(measure.implicitHeight, Theme.messageExpandLines * lineHeight)

                    Layout.fillWidth: true
                    visible: root.body !== ""
                    implicitHeight: Math.floor(lineHeight + root.expansion * (fullHeight - lineHeight))
                    clip: true

                    Text {
                        id: measureLine
                        visible: false
                        text: "M"
                        font: bodyText.font
                    }
                    Text {
                        id: measure
                        width: parent.width
                        visible: false
                        text: bodyText.text
                        textFormat: bodyText.textFormat
                        wrapMode: Text.Wrap
                        font: bodyText.font
                    }
                    Text {
                        id: bodyText
                        width: parent.width
                        text: root.body.replace(/\n/g, " ")
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: root.expansion > 0 ? Theme.messageExpandLines : 1
                        color: Theme.fgColor
                        linkColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }

            RowLayout {
                id: controlsRow
                Layout.fillHeight: true
                spacing: 0
            }
        }

        // ───────── Aktionen ─────────
        Item {
            id: actionBin

            Layout.fillWidth: true
            visible: root.actions.length > 0 && root.expansion > 0
            implicitHeight: Math.round(actionRow.implicitHeight * root.expansion)
            clip: true

            RowLayout {
                id: actionRow
                x: 0
                y: 0
                width: parent.width
                spacing: Theme.messageActionSpacing + 2 * Theme.messageActionPadding

                Repeater {
                    model: root.actions.slice(0, 3)

                    Button {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.messageActionPadding
                        Layout.bottomMargin: Theme.messageActionPadding
                        notification: true
                        text: modelData.label
                        onClicked: modelData.trigger()
                    }
                }
            }
        }
    }
}
