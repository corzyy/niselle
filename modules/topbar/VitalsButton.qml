import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Vitals: CPU-Last, Arbeitsspeicher, Temperatur und Netzwerkdurchsatz als kurze Werte in der Leiste (welche, steht in den
// Einstellungen). Klick öffnet ein Fenster mit allen Werten samt Balken, Swap, Systemlast und Laufzeit. Gemessen wird nur,
// solange das Element in der Leiste steht (VitalsService.active).
Pill {
    id: root

    property color foreground: Theme.panelFg

    // Zeitpunkt, an dem das Fenster zuletzt geschlossen wurde: der Klick, der per Fokus-Grab schloss, soll es nicht wieder öffnen
    property double closedAt: 0

    function pct(v) {
        return Math.round(v) + "%";
    }
    function formatUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
    }

    fg: foreground
    inset: Theme.panelButtonBorder
    checked: popup.open
    spacing: Theme.basePadding * 2

    Binding {
        target: VitalsService
        property: "active"
        value: true
    }

    onClicked: m => {
        if (m && m.button !== Qt.LeftButton)
            return;
        if (!popup.open && Date.now() - root.closedAt < 200)
            return;
        popup.toggle();
    }

    // Wert mit dimmer Beschriftung; feste Mindestbreite, damit die Leiste nicht zittert
    component Metric: RowLayout {
        property string label: ""
        property string value: ""
        property string widest: "100%"

        spacing: 4

        PanelText {
            text: parent.label
            color: root.fg
            opacity: 0.6
            font.weight: Theme.fontWeightNormal
        }
        PanelText {
            text: parent.value
            color: root.fg
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: metrics.width

            TextMetrics {
                id: metrics
                font: parent.font
                text: parent.parent.widest
            }
        }
    }

    Metric {
        visible: SettingsService.barVitalsCpu
        label: "CPU"
        value: root.pct(VitalsService.cpu)
    }
    Metric {
        visible: SettingsService.barVitalsMemory
        label: "RAM"
        value: root.pct(VitalsService.memPercent)
    }
    Metric {
        visible: SettingsService.barVitalsTemp && VitalsService.temperature >= 0
        label: "Temp"
        value: Math.round(VitalsService.temperature) + "°C"
        widest: "100°C"
    }
    Metric {
        visible: SettingsService.barVitalsNet
        label: "↓"
        value: VitalsService.formatRate(VitalsService.netDown)
        widest: "999 MB/s"
    }
    Metric {
        visible: SettingsService.barVitalsNet
        label: "↑"
        value: VitalsService.formatRate(VitalsService.netUp)
        widest: "999 MB/s"
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

        minWidth: 320
        grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"
        onOpenChanged: if (!open)
            root.closedAt = Date.now()

        // Zeile mit Beschriftung, Wert und optionalem Balken (0–1)
        component VitalRow: ColumnLayout {
            property string label: ""
            property string value: ""
            property real fraction: -1
            property color barColor: Theme.accentColor

            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: parent.parent.label
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: parent.parent.value
                    color: Theme.alpha(Theme.fgColor, 0.7)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.features: ({
                            "tnum": 1
                        })
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                visible: parent.fraction >= 0
                radius: 3
                color: Theme.alpha(Theme.fgColor, 0.12)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction))
                    height: parent.height
                    radius: 3
                    color: parent.parent.barColor

                    Behavior on width {
                        enabled: !Theme.gameMode
                        NumberAnimation {
                            duration: 300
                            easing.type: Theme.easeOutCubic
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 296
            Layout.margins: 6
            spacing: 14

            VitalRow {
                label: "Processor"
                value: root.pct(VitalsService.cpu)
                fraction: VitalsService.cpu / 100
                barColor: VitalsService.cpu > 90 ? Theme.destructive : Theme.accentColor
            }
            VitalRow {
                label: "Memory"
                value: VitalsService.formatBytes(VitalsService.memUsed) + " of " + VitalsService.formatBytes(VitalsService.memTotal)
                fraction: VitalsService.memPercent / 100
                barColor: VitalsService.memPercent > 90 ? Theme.destructive : Theme.accentColor
            }
            VitalRow {
                visible: VitalsService.swapTotal > 0
                label: "Swap"
                value: VitalsService.formatBytes(VitalsService.swapUsed) + " of " + VitalsService.formatBytes(VitalsService.swapTotal)
                fraction: VitalsService.swapUsed / VitalsService.swapTotal
            }
            VitalRow {
                visible: VitalsService.temperature >= 0
                label: "Temperature"
                value: Math.round(VitalsService.temperature) + " °C"
                fraction: VitalsService.temperature / 100
                barColor: VitalsService.temperature > 85 ? Theme.destructive : Theme.accentColor
            }
            VitalRow {
                label: "Network"
                value: "↓ " + VitalsService.formatRate(VitalsService.netDown) + "   ↑ " + VitalsService.formatRate(VitalsService.netUp)
            }
            VitalRow {
                label: "Load Average"
                value: VitalsService.load.map(l => l.toFixed(2)).join("  ")
            }
            VitalRow {
                label: "Uptime"
                value: root.formatUptime(VitalsService.uptime)
            }
        }
    }
}
