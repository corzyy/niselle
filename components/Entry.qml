import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property alias text: input.text
    property string placeholderText: ""
    property bool password: false
    property real paddingV: Theme.entryPaddingV
    property bool revealed: false

    readonly property bool hovered: hover.hovered
    readonly property bool focused: input.activeFocus

    signal accepted

    function forceFocus() {
        input.forceActiveFocus();
    }
    function clear() {
        input.text = "";
        revealed = false;
    }

    implicitWidth: Theme.dialogEntryWidth
    implicitHeight: input.implicitHeight + 2 * paddingV

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusEntry
        color: root.focused ? Theme.mix(Theme.accentText, Theme.entryBg, 0.05) : (root.hovered ? Theme.entryBgHover : Theme.entryBg)

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusEntry
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRing
        opacity: root.focused ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }
    }

    HoverHandler {
        id: hover
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.entryPaddingH
        anchors.rightMargin: Theme.entryPaddingH
        spacing: Theme.spacingSm

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: input.implicitHeight

            TextInput {
                id: input
                anchors.fill: parent
                color: root.focused ? Theme.entryFg : Theme.entryFgIdle
                selectionColor: Theme.entrySelection
                selectedTextColor: Theme.fgColor
                echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
                passwordCharacter: "●"
                clip: true
                selectByMouse: true
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
                font.weight: Theme.fontWeightNormal
                verticalAlignment: TextInput.AlignVCenter
                onAccepted: root.accepted()
            }

            Text {
                anchors.fill: parent
                visible: input.text === "" && root.placeholderText !== ""
                text: root.placeholderText
                color: Theme.entryHint
                elide: Text.ElideRight
                font: input.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        Icon {
            visible: root.password
            name: root.revealed ? "view-conceal-symbolic" : "view-reveal-symbolic"
            color: root.revealed ? Theme.fgColor : Theme.entryFgIdle

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.spacingSm
                cursorShape: Qt.ArrowCursor
                onClicked: root.revealed = !root.revealed
            }
        }
    }
}
