import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs
import qs.components

// Polkit-Authentifizierungsdialog (polkitAgent.js, AuthenticationDialog) [_dialogs.scss:99-159]: Titel „Authentication
// Required“, Meldung der Aktion, Avatar und Name des Benutzers, Passwortfeld mit Spinner, Fehler-/Infozeile,
// Abbrechen / Authenticate. Registriert sich zugleich als Polkit-Agent der Sitzung.
Scope {
    id: root

    readonly property var flow: agent.flow
    // Auf eine Antwort von PAM warten (nach dem Absenden, bis die nächste Frage oder das Ergebnis kommt)
    readonly property bool busy: flow !== null && !flow.isResponseRequired && !flow.isCompleted
    readonly property string errorText: {
        if (!flow)
            return "";
        if (flow.supplementaryIsError && flow.supplementaryMessage !== "")
            return flow.supplementaryMessage;
        return flow.failed ? "Sorry, that didn’t work. Please try again." : "";
    }
    readonly property string infoText: flow && !flow.supplementaryIsError ? flow.supplementaryMessage : ""

    // Wie die Shell: der eigene Benutzer, sonst root, sonst der erste
    function _unixName(identity) {
        return (identity.string ?? "").replace(/^unix-user:/, "");
    }
    function _pickIdentity(flow) {
        const list = flow.identities;
        const names = list.map(i => _unixName(i));
        let i = names.indexOf(Quickshell.env("USER"));
        if (i < 0)
            i = names.indexOf("root");
        return list[Math.max(i, 0)];
    }

    property string userName: ""
    property string realName: ""
    readonly property bool isRoot: userName === "root"

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            if (flow.identities.length > 0)
                flow.selectedIdentity = root._pickIdentity(flow);
            root.userName = flow.selectedIdentity ? root._unixName(flow.selectedIdentity) : "";
            passwordEntry.clear();
        }
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            dialog.wiggle();
            passwordEntry.clear();
        }
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired)
                focusTimer.restart();
        }
    }

    // Vollständiger Name aus dem Passwortverzeichnis (GECOS)
    Process {
        running: root.userName !== ""
        command: ["getent", "passwd", root.userName]
        stdout: StdioCollector {
            onStreamFinished: root.realName = (text.split(":")[4] ?? "").split(",")[0].trim()
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: passwordEntry.forceFocus()
    }

    function submit() {
        if (flow && flow.isResponseRequired && passwordEntry.text.length > 0)
            flow.submit(passwordEntry.text);
    }

    ModalDialog {
        id: dialog

        open: agent.isActive
        dialogWidth: Theme.dialogPromptWidth
        title: "Authentication Required"
        description: root.flow ? root.flow.message : ""
        buttons: [
            {
                "id": "cancel",
                "text": "Cancel"
            },
            {
                "id": "authenticate",
                "text": "Authenticate",
                "primary": true
            }
        ]
        disabledButtons: passwordEntry.text.length === 0 || !root.flow || !root.flow.isResponseRequired ? ["authenticate"] : []

        onOpenChanged: {
            if (open)
                focusTimer.restart();
        }
        onCanceled: if (root.flow)
            root.flow.cancelAuthenticationRequest()
        onButtonClicked: id => {
            if (id === "authenticate")
                root.submit();
            else if (root.flow)
                root.flow.cancelAuthenticationRequest();
        }

        // .polkit-dialog-user-layout
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.basePadding
            spacing: Theme.baseMargin * 2

            Avatar {
                Layout.alignment: Qt.AlignHCenter
                userName: root.userName
                size: 64
            }
            Text {
                Layout.fillWidth: true
                text: root.isRoot ? "Administrator" : (root.realName !== "" ? root.realName : root.userName)
                color: root.isRoot ? Theme.warning : Theme.fgColor
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeTitle4
                font.weight: Theme.fontWeightBold
            }
        }

        // .prompt-dialog-password-layout: Eintrag mit Spinner daneben; der linke Abstand hält den Eintrag mittig
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.baseMargin

            Item {
                implicitWidth: Theme.iconSize
            }
            Entry {
                id: passwordEntry
                paddingV: Theme.dialogEntryPaddingV
                password: !(root.flow && root.flow.responseVisible)
                enabled: !root.busy
                opacity: enabled ? 1 : 0.5
                placeholderText: root.flow ? root.flow.inputPrompt.replace(/:\s*$/, "") : ""
                onAccepted: root.submit()
            }
            Spinner {
                running: root.busy
                hideOnStop: false
                opacity: running ? 1 : 0
            }
        }

        // Fehler-/Infozeile; ohne Text bleibt die Höhe erhalten (.prompt-dialog-null-label), damit der Dialog nicht springt
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.baseMargin
            Layout.bottomMargin: Theme.baseMargin
            implicitHeight: Math.max(message.implicitHeight, Theme.fontSizeCaption * 1.5) + 2 * Theme.dialogLabelPadding
            radius: Theme.radiusButton
            color: root.errorText !== "" ? Theme.dialogWarningBg : (root.infoText !== "" ? Theme.transparentize(Theme.fgColor, 0.9) : "transparent")

            Text {
                id: message
                anchors.fill: parent
                anchors.margins: Theme.dialogLabelPadding
                text: root.errorText !== "" ? root.errorText : root.infoText
                color: root.errorText !== "" ? Theme.warning : Theme.fgColor
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightNormal
            }
        }
    }
}
