import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

FocusScope {
    id: root

    property string screenName: ""

    property real progress: LockService.dialogShown ? 1 : 0
    readonly property bool dialogShown: LockService.dialogShown

    Behavior on progress {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: 400
            easing.type: Theme.easeOutQuad
        }
    }

    readonly property bool showUi: !OverviewService.primaryScreen || screenName === OverviewService.primaryScreen.name
    readonly property real bgProgress: showUi ? progress : 1

    readonly property color white: "#ffffff"
    readonly property string wallpaper: WallpaperService.sourceFor(screenName)

    focus: true

    onDialogShownChanged: {
        if (dialogShown)
            focusTimer.restart();
        else
            root.forceActiveFocus();
    }
    Component.onCompleted: {
        if (dialogShown)
            focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: input.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (LockService.dialogShown) {
            if (!root.showUi && !LockService.busy) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    LockService.submit();
                else if (event.key === Qt.Key_Backspace)
                    LockService.password = LockService.password.slice(0, -1);
                else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier)))
                    LockService.password += event.text;
                else
                    return;
                event.accepted = true;
            }
            return;
        }
        const modifiers = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock, Qt.Key_Super_L, Qt.Key_Super_R];
        if (modifiers.indexOf(event.key) >= 0 || event.key === Qt.Key_Escape)
            return;
        if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier)))
            LockService.password = event.text;
        LockService.showDialog();
        event.accepted = true;
    }
    Keys.onEscapePressed: {
        if (LockService.dialogShown)
            LockService.showCurtain();
    }

    Rectangle {
        anchors.fill: parent
        color: "#1d1d20"
    }

    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width, root.height)
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: !Theme.gameMode
        blurMax: 64
        blur: SettingsService.lockBlurCurtain ? 1 : root.bgProgress
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: SettingsService.lockBlurCurtain ? 0.45 : 0.45 * root.bgProgress
    }

    Rectangle {
        anchors.fill: parent
        opacity: 1 - root.progress
        visible: opacity > 0
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(0, 0, 0, 0.42)
            }
            GradientStop {
                position: 0.32
                color: "transparent"
            }
            GradientStop {
                position: 0.7
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0, 0, 0, 0.42)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.dialogShown
        onPressed: LockService.showDialog()
        onWheel: LockService.showDialog()
    }

    Item {
        id: clockPage
        width: parent.width
        height: parent.height
        y: -root.height * root.progress
        opacity: 1 - root.progress
        visible: root.showUi && opacity > 0

        LockClock {
            anchors.fill: parent
            active: root.progress === 0
        }
    }

    Item {
        id: dialogPage
        anchors.fill: parent
        opacity: root.progress
        visible: root.showUi && opacity > 0
        transform: Translate {
            y: (1 - root.progress) * 60
        }

        Column {
            id: dialog
            anchors.centerIn: parent
            spacing: 18
            width: Math.min(parent.width - 48, Theme.lockDialogWidth)

            transform: Translate {
                id: shake
            }

            Item {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 112
                height: 112

                readonly property var candidates: ["file://" + Quickshell.env("HOME") + "/.face", "file:///var/lib/AccountsService/icons/" + LockService.userName]
                property int candidate: 0

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.18)
                    visible: face.status !== Image.Ready

                    Icon {
                        anchors.centerIn: parent
                        name: "avatar-default-symbolic"
                        size: 56
                        color: root.white
                    }
                }

                Image {
                    id: face
                    anchors.fill: parent
                    source: avatar.candidate < avatar.candidates.length ? avatar.candidates[avatar.candidate] : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    sourceSize: Qt.size(avatar.width * 2, avatar.height * 2)
                    onStatusChanged: {
                        if (status === Image.Error)
                            avatar.candidate++;
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: LockService.realName !== "" ? LockService.realName : LockService.userName
                color: root.white
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.lockNameFontSize
                font.weight: Theme.fontWeightNormal
            }

            Item {
                width: parent.width
                height: input.implicitHeight + 2 * Theme.dialogEntryPaddingV
                opacity: LockService.busy ? 0.5 : 1

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.lockEntryRadius
                    color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.16) : (fieldHover.hovered ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.1))

                    Behavior on color {
                        enabled: !Theme.gameMode
                        ColorAnimation {
                            duration: Theme.durationButton
                            easing.type: Theme.easeOut
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.lockEntryRadius
                    color: "transparent"
                    border.width: Theme.focusRingWidth
                    border.color: Qt.rgba(1, 1, 1, 0.4)
                    opacity: input.activeFocus ? 1 : 0

                    Behavior on opacity {
                        enabled: !Theme.gameMode
                        NumberAnimation {
                            duration: Theme.durationButton
                            easing.type: Theme.easeOut
                        }
                    }
                }

                HoverHandler {
                    id: fieldHover
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.dialogEntryPaddingV
                    anchors.rightMargin: Theme.dialogEntryPaddingV
                    spacing: Theme.spacingSm

                    Item {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: input.implicitHeight

                        TextInput {
                            id: input
                            anchors.fill: parent
                            property bool revealed: false
                            color: root.white
                            selectionColor: Theme.entrySelection
                            selectedTextColor: root.white
                            echoMode: revealed ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "●"
                            clip: true
                            enabled: !LockService.busy
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            verticalAlignment: TextInput.AlignVCenter
                            onTextEdited: LockService.password = text
                            onAccepted: LockService.submit()
                        }

                        Binding {
                            target: input
                            property: "text"
                            value: LockService.password
                        }

                        Text {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: "Password"
                            color: Qt.rgba(1, 1, 1, 0.7)
                            font: input.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Icon {
                        name: input.revealed ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        color: input.revealed ? root.white : Qt.rgba(1, 1, 1, 0.7)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.spacingSm
                            onClicked: input.revealed = !input.revealed
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.lockMessageMinHeight

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignTop
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: LockService.errorMessage
                    color: root.white
                    opacity: text !== "" ? 0.85 : 0
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase

                    Behavior on opacity {
                        enabled: !Theme.gameMode
                        NumberAnimation {
                            duration: Theme.durationButton
                            easing.type: Theme.easeOut
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 12

                Repeater {
                    model: [
                        {
                            "text": "Cancel",
                            "primary": false
                        },
                        {
                            "text": "Unlock",
                            "primary": true
                        }
                    ]

                    Item {
                        id: btn
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: Theme.lockButtonHeight
                        opacity: modelData.primary && (LockService.busy || LockService.password === "") ? 0.5 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.lockButtonRadius
                            color: {
                                const down = btnMouse.pressed, over = btnMouse.containsMouse;
                                if (btn.modelData.primary)
                                    return down ? Theme.darken(Theme.accentColor, 0.1) : (over ? Theme.lighten(Theme.accentColor, 0.07) : Theme.accentColor);
                                return Qt.rgba(1, 1, 1, down ? 0.24 : (over ? 0.18 : 0.12));
                            }

                            Behavior on color {
                                enabled: !Theme.gameMode
                                ColorAnimation {
                                    duration: Theme.durationButton
                                    easing.type: Theme.easeOut
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: btn.modelData.text
                            color: btn.modelData.primary ? Theme.accentFg : root.white
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.lockButtonFontSize
                            font.weight: Theme.fontWeightBold
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: btn.modelData.primary ? LockService.submit() : LockService.showCurtain()
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: wiggle
        NumberAnimation {
            target: shake
            property: "x"
            to: -14
            duration: 50
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: 14
            duration: 80
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: -9
            duration: 80
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: 9
            duration: 70
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: 0
            duration: 50
            easing.type: Easing.InOutSine
        }
    }

    Connections {
        target: LockService
        function onFailuresChanged() {
            if (!Theme.gameMode)
                wiggle.restart();
        }
        function onBusyChanged() {
            if (!LockService.busy && LockService.dialogShown)
                focusTimer.restart();
        }
    }
}
