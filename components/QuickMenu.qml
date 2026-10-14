import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property bool open: false
    property string headerIcon: ""
    property string headerTitle: ""
    property string headerSubtitle: ""
    property bool headerActive: false

    default property alias content: column.data
    property alias headerSuffix: suffix.data

    property real reveal: 0
    property real fade: 0

    readonly property bool shown: reveal > 0 || open || fade > 0
    readonly property real naturalHeight: card.implicitHeight

    signal closed
    signal closeRequested

    readonly property var menuOwner: root

    function close() {
        closeRequested();
    }

    visible: shown
    height: reveal * naturalHeight

    onOpenChanged: {
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
