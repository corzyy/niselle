import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Update-Element der Leiste: bleibt unsichtbar, bis Aktualisierungen bereitstehen (UpdateService). Klick öffnet das
// Update-Fenster mit der Paketliste; „Install“ startet `pkexec dnf5 upgrade` (Polkit-Anmeldung über den Agenten der Shell),
// danach zeigt das Fenster den Fortschritt und das Ergebnis.
Pill {
    id: root

    property color foreground: Theme.panelFg

    // Zeitpunkt, an dem das Fenster zuletzt geschlossen wurde: der Klick, der per Fokus-Grab schloss, soll es nicht wieder öffnen
    property double closedAt: 0

    readonly property string state: UpdateService.state
    readonly property bool showResult: state === "done" || state === "failed"

    fg: foreground
    inset: Theme.panelButtonBorder
    checked: popup.open
    visible: UpdateService.available || UpdateService.installing || showResult

    onClicked: m => {
        if (m && m.button !== Qt.LeftButton)
            return;
        if (!popup.open && Date.now() - root.closedAt < 200)
            return;
        popup.toggle();
    }

    Spinner {
        running: UpdateService.installing
        color: root.fg
        size: Theme.iconSize
    }
    Icon {
        visible: !UpdateService.installing
        name: root.state === "done" ? "emblem-ok-symbolic" : root.state === "failed" ? "dialog-warning-symbolic" : "software-update-available-symbolic"
        color: root.fg
        size: Theme.iconSize
    }
    PanelText {
        visible: UpdateService.available && !UpdateService.installing
        text: UpdateService.count
        color: root.fg
    }

    PopupMenu {
        id: popup

        anchor.item: root
        anchor.rect.x: root.width / 2
        anchor.rect.y: root.height + Theme.popoverRise - margin - 1
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.None

        minWidth: 360
        grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"
        onOpenChanged: if (!open)
            root.closedAt = Date.now()

        ColumnLayout {
            Layout.preferredWidth: 336
            Layout.margins: 4
            spacing: 12

            // Kopf: Symbol, Titel, Untertitel
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: root.state === "failed" ? Theme.alpha(Theme.destructive, 0.2) : Theme.alpha(Theme.accentColor, 0.2)

                    Spinner {
                        anchors.centerIn: parent
                        running: UpdateService.installing || UpdateService.checking
                        color: Theme.accentText
                        size: 22
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !UpdateService.installing && !UpdateService.checking
                        name: root.state === "done" ? "emblem-ok-symbolic" : root.state === "failed" ? "dialog-warning-symbolic" : "software-update-available-symbolic"
                        size: 22
                        color: root.state === "failed" ? Theme.destructive : Theme.accentText
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.state === "installing" ? "Installing updates …" : root.state === "done" ? "Up to date" : root.state === "failed" ? "Update failed" : UpdateService.count + (UpdateService.count === 1 ? " update available" : " updates available")
                        elide: Text.ElideRight
                        color: Theme.fgColor
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase * 1.15
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.state === "installing" ? "Please keep your computer on" : root.state === "done" ? "Some updates may need a restart" : root.state === "failed" ? "See the details below" : UpdateService.checking ? "Checking for updates …" : "Checked " + Qt.formatTime(UpdateService.lastChecked, "HH:mm")
                        elide: Text.ElideRight
                        color: Theme.alpha(Theme.fgColor, 0.6)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                    }
                }
            }

            // Paketliste
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, list.contentHeight + 8)
                visible: UpdateService.available && !UpdateService.installing && !root.showResult
                radius: Theme.radiusButton
                color: Theme.alpha(Theme.fgColor, 0.06)
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 4
                    model: UpdateService.updates
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    delegate: RowLayout {
                        id: row

                        required property var modelData

                        width: ListView.view.width
                        height: 28
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: Theme.fgColor
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                        }
                        Text {
                            Layout.maximumWidth: 150
                            Layout.rightMargin: 8
                            text: row.modelData.version
                            elide: Text.ElideRight
                            color: Theme.alpha(Theme.fgColor, 0.55)
                            font.family: Theme.fontFamilyMono
                            font.pointSize: Theme.fontSizeCaption
                        }
                    }
                }
            }

            // Installation: letzte Ausgabezeile und unbestimmter Balken
            ColumnLayout {
                Layout.fillWidth: true
                visible: UpdateService.installing
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Theme.alpha(Theme.fgColor, 0.12)
                    clip: true

                    Rectangle {
                        id: sweep
                        width: parent.width * 0.3
                        height: parent.height
                        radius: 2
                        color: Theme.accentColor

                        SequentialAnimation on x {
                            running: UpdateService.installing && !Theme.gameMode
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: -sweep.width
                                to: sweep.parent.width
                                duration: 1200
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: UpdateService.status
                    elide: Text.ElideMiddle
                    color: Theme.alpha(Theme.fgColor, 0.6)
                    font.family: Theme.fontFamilyMono
                    font.pointSize: Theme.fontSizeCaption
                }
            }

            // Fehlertext
            Text {
                Layout.fillWidth: true
                visible: root.state === "failed"
                text: UpdateService.error
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                color: Theme.alpha(Theme.fgColor, 0.7)
                font.family: Theme.fontFamilyMono
                font.pointSize: Theme.fontSizeCaption
            }

            // Aktionen
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !UpdateService.installing

                Button {
                    visible: !root.showResult
                    text: "Check Again"
                    enabled: !UpdateService.checking
                    onClicked: UpdateService.check()
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    visible: root.showResult
                    text: root.state === "failed" ? "Dismiss" : "Close"
                    onClicked: {
                        popup.close();
                        UpdateService.dismiss();
                    }
                }
                Button {
                    visible: root.state === "failed" || (!root.showResult && UpdateService.available)
                    primary: true
                    text: root.state === "failed" ? "Try Again" : "Install " + (UpdateService.count === 1 ? "Update" : "All Updates")
                    enabled: UpdateService.available && !UpdateService.checking
                    onClicked: UpdateService.install()
                }
            }
        }
    }
}
