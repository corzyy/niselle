import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

FloatingWindow {
    id: win

    title: "Matugen Install"
    color: Theme.windowBg
    implicitWidth: 560
    implicitHeight: 460
    minimumSize: Qt.size(420, 300)

    onClosed: MatugenInstallService.open = false

    function colorFor(kind) {
        switch (kind) {
        case "ok":
            return Theme.accentColor;
        case "warn":
            return Theme.warning;
        case "error":
            return Theme.error;
        case "skip":
            return Theme.alpha(Theme.windowFg, 0.5);
        case "step":
            return Theme.windowFg;
        default:
            return Theme.alpha(Theme.windowFg, 0.75);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Spinner {
                running: MatugenInstallService.running
            }
            Text {
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBase
                font.bold: true
                color: Theme.windowFg
                text: MatugenInstallService.running ? "Installing Matugen themes …" : (MatugenInstallService.summary !== "" ? MatugenInstallService.summary : "Matugen Install")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusButton
            color: Theme.cardBg
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 10
                model: MatugenInstallService.entries
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                onCountChanged: Qt.callLater(() => list.positionViewAtEnd())

                delegate: Text {
                    required property var modelData
                    width: list.width
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamilyMono
                    font.pixelSize: Theme.fontSizeBase - 1
                    font.bold: modelData.kind === "step"
                    color: win.colorFor(modelData.kind)
                    text: (modelData.kind === "step" ? "▸ " : "   ") + modelData.text
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: MatugenInstallService.running ? "Running …" : "Close"
                primary: true
                enabled: !MatugenInstallService.running
                onClicked: MatugenInstallService.close()
            }
        }
    }
}
