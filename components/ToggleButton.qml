import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool checked: false
    property bool hasMenu: false
    property string menuIcon: "go-next-symbolic"
    property bool iconSymbolic: true

    readonly property string buttonState: Theme.buttonState(main.containsMouse, main.pressed, false, enabled, activeFocus)
    readonly property string menuButtonState: Theme.buttonState(menu.containsMouse, menu.pressed, false, enabled, false)

    readonly property color fg: checked ? Theme.accentFg : Theme.fgColor

    readonly property real pillRadius: height / 2

    signal clicked
    signal menuClicked

    implicitWidth: Theme.quickToggleWidth
    implicitHeight: Theme.quickToggleHeight
    activeFocusOnTab: true

    Rectangle {
        id: mainBg

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.hasMenu ? parent.width - menuSegment.width - Theme.quickToggleSeparatorWidth : parent.width
        radius: root.pillRadius
        topRightRadius: root.hasMenu ? 0 : radius
        bottomRightRadius: root.hasMenu ? 0 : radius

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeOut
            }
        }
        color: root.checked
            ? Theme.buttonBg(root.buttonState, {"bg": Theme.accentColor, "fg": Theme.accentFg, "style": "default"})
            : Theme.glass(Theme.buttonBg(root.buttonState, {}))
    }

    Rectangle {
        anchors.fill: mainBg
        topRightRadius: mainBg.topRightRadius
        bottomRightRadius: mainBg.bottomRightRadius
        radius: root.pillRadius
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: root.checked ? Theme.focusRingDefault : Theme.focusRing
        opacity: root.activeFocus ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    RowLayout {
        anchors.fill: mainBg
        anchors.leftMargin: Theme.quickToggleIconLeading
        anchors.rightMargin: root.hasMenu ? Theme.basePadding * 1.5 : Theme.quickToggleHPadding
        spacing: Theme.quickToggleSpacing

        Icon {
            name: root.icon
            color: root.enabled ? root.fg : Theme.buttonFgInsensitive(root.fg)
            symbolic: root.iconSymbolic
            visible: root.icon !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.enabled ? root.fg : Theme.buttonFgInsensitive(root.fg)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeHeading
                font.weight: Theme.fontWeightBold
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: root.enabled ? root.fg : Theme.buttonFgInsensitive(root.fg)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightNormal
            }
        }
    }

    MouseArea {
        id: main

        anchors.fill: mainBg
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Rectangle {
        visible: root.hasMenu
        x: mainBg.width
        width: Theme.quickToggleSeparatorWidth
        height: parent.height
        color: root.checked ? Theme.quickToggleCheckedSeparator : Theme.quickToggleSeparator
    }

    Item {
        id: menuSegment

        visible: root.hasMenu
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.iconSize + 2 * Theme.quickToggleMenuButtonPaddingH
        clip: true

        Rectangle {
            x: -root.pillRadius
            width: parent.width + root.pillRadius
            height: parent.height
            radius: root.pillRadius

            color: root.checked
                ? Theme.buttonBg(root.menuButtonState, {"bg": Theme.quickToggleMenuButtonCheckedBg, "fg": Theme.accentFg, "style": "default"})
                : Theme.buttonBg(root.menuButtonState, {"bg": Theme.quickToggleMenuButtonBg})
        }

        Icon {
            anchors.centerIn: parent
            name: root.menuIcon
            color: root.checked ? Theme.accentFg : Theme.fgColor
        }

        MouseArea {
            id: menu

            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.menuClicked()
        }
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
