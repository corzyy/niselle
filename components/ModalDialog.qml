import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

// Modaler Dialog (ModalDialog, .modal-dialog) [_dialogs.scss:1-21, 85-130]: dunkelt den Bildschirm ab, Karte mit
// Radius 18, Padding 24, Titel (title-2, zentriert), Beschreibung, eigener Inhalt, Knopfreihe. Nimmt die Tastatur
// exklusiv. Esc bricht ab.
//
// buttons: [{ id, text, primary }]; primary = Standardknopf (Akzent), wird mit Enter ausgelöst.
PanelWindow {
    id: root

    property bool open: false
    property string title: ""
    property string description: ""
    property var buttons: []
    property real dialogWidth: 0
    // Knopf mit dieser id ist gesperrt
    property var disabledButtons: []

    default property alias content: contentColumn.data

    signal buttonClicked(string id)
    signal canceled

    // Einblenden / Ausblenden
    property real shade: 0

    function _primary() {
        return buttons.find(b => b.primary) ?? null;
    }
    // Wackeln (Util.wiggle), z. B. bei falschem Passwort
    function wiggle() {
        if (!Theme.gameMode)
            wiggleAnimation.restart();
    }
    function _activate(b) {
        if (b && disabledButtons.indexOf(b.id) < 0)
            buttonClicked(b.id);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || shade > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-dialog"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: shade = open ? 1 : 0

    Behavior on shade {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.durationDialog
            easing.type: Theme.easeOutQuad
        }
    }

    // Abdunklung; fängt alle Klicks ab (modal)
    Rectangle {
        anchors.fill: parent
        color: Theme.dialogShade
        opacity: root.shade

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: root.canceled()
        Keys.onReturnPressed: root._activate(root._primary())
        Keys.onEnterPressed: root._activate(root._primary())

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.max(root.dialogWidth, layout.implicitWidth + 2 * Theme.dialogPadding)
            height: layout.implicitHeight + 2 * Theme.dialogPadding
            radius: Theme.radiusAlert
            color: Theme.bgColor
            opacity: root.shade

            transform: Translate {
                id: shake
            }

            SequentialAnimation {
                id: wiggleAnimation
                NumberAnimation { target: shake; property: "x"; to: -14; duration: 50; easing.type: Easing.InOutSine }
                NumberAnimation { target: shake; property: "x"; to: 14; duration: 80; easing.type: Easing.InOutSine }
                NumberAnimation { target: shake; property: "x"; to: -9; duration: 80; easing.type: Easing.InOutSine }
                NumberAnimation { target: shake; property: "x"; to: 9; duration: 70; easing.type: Easing.InOutSine }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 50; easing.type: Easing.InOutSine }
            }

            ColumnLayout {
                id: layout
                anchors.fill: parent
                anchors.margins: Theme.dialogPadding
                spacing: Theme.dialogSpacing

                // .modal-dialog-content-box
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dialogContentPaddingTop
                    Layout.maximumWidth: Theme.dialogContentMaxWidth
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.dialogSpacing

                    Text {
                        Layout.fillWidth: true
                        visible: root.title !== ""
                        text: root.title
                        color: Theme.fgColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeTitle2
                        font.weight: Theme.fontWeightExtraBold
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.description !== ""
                        text: root.description
                        color: Theme.fgColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightNormal
                    }
                    ColumnLayout {
                        id: contentColumn
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.dialogSpacing
                    }
                }

                // .modal-dialog-button-box
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dialogButtonBoxPaddingTop
                    spacing: Theme.spacingLg

                    Repeater {
                        model: root.buttons

                        Item {
                            id: button

                            required property var modelData
                            readonly property bool primary: modelData.primary === true
                            readonly property bool locked: root.disabledButtons.indexOf(modelData.id) >= 0
                            readonly property string buttonState: Theme.buttonState(mouse.containsMouse, mouse.pressed, false, !locked, activeFocus)
                            readonly property color fg: primary ? Theme.accentFg : Theme.fgColor

                            Layout.fillWidth: true
                            implicitHeight: label.implicitHeight + 2 * Theme.dialogButtonPadding
                            activeFocusOnTab: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusDialogButton
                                color: button.primary ? Theme.buttonBg(button.buttonState, {
                                    "bg": Theme.accentColor,
                                    "fg": Theme.accentFg,
                                    "style": "default"
                                }) : Theme.buttonBg(button.buttonState, {
                                    "style": "dialog"
                                })

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
                                radius: Theme.radiusDialogButton
                                color: "transparent"
                                border.width: Theme.focusRingWidth
                                border.color: button.primary ? Theme.focusRingDefault : Theme.focusRing
                                opacity: button.activeFocus ? 1 : 0
                            }
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: button.modelData.text
                                color: button.locked ? Theme.buttonFgInsensitive(button.fg) : button.fg
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSizeBase
                                font.weight: Theme.fontWeightBold
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root._activate(button.modelData)
                            }
                            Keys.onReturnPressed: root._activate(button.modelData)
                            Keys.onSpacePressed: root._activate(button.modelData)
                        }
                    }
                }
            }
        }
    }
}
