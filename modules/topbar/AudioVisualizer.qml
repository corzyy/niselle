import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.components

// Audio-Visualisierung: Balken zum Spektrum des Systemtons (bin/niselle-audio-bands, parec + Goertzel). Erscheint nur,
// solange ein Medienspieler spielt; nur dann läuft auch der Hilfsprozess. Klick: Wiedergabe/Pause.
Pill {
    id: root

    property color foreground: Theme.panelFg

    readonly property int bars: SettingsService.barVisualizerBars
    readonly property bool active: MediaService.playing
    property var levels: []

    fg: foreground
    inset: Theme.panelButtonBorder
    visible: active

    onClicked: m => {
        if (!m || m.button === Qt.LeftButton)
            MediaService.playPause();
    }

    Process {
        id: analyzer
        running: root.active
        command: [Quickshell.shellPath("bin/niselle-audio-bands"), String(root.bars)]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(" ").map(Number)
        }
        onRunningChanged: if (!running)
            root.levels = []
    }

    // Bei geänderter Balkenzahl den Prozess mit neuem Argument neu starten
    onBarsChanged: {
        if (analyzer.running) {
            analyzer.running = false;
            restart.restart();
        }
    }
    Timer {
        id: restart
        interval: 150
        onTriggered: analyzer.running = root.active
    }

    Row {
        id: row
        spacing: 2
        Layout.alignment: Qt.AlignVCenter

        Repeater {
            model: root.bars

            Rectangle {
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 2 + (root.levels[index] ?? 0) / 100 * (Theme.iconSize - 2)
                radius: width / 2
                color: root.fg
            }
        }
    }
}
