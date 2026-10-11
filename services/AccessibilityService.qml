pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Barrierefreiheit: Größere Schrift und weniger Bewegung wirken über Theme (shell.qml), der Bildschirmleser
// ist Orca, der läuft, solange der Schalter an ist. `available` ist nur ein Anker, damit shell.qml das Singleton lädt.
Singleton {
    id: root

    readonly property bool available: true

    // Orca ist installiert
    property bool screenReaderAvailable: false
    readonly property bool screenReaderRunning: SettingsService.a11yScreenReader && screenReaderAvailable

    // Alle Schalter des Menüs, in Anzeigereihenfolge: [Schlüssel, Titel, Icon, verfügbar]
    readonly property var options: [
        {
            "key": "a11yLargeText",
            "title": "Large Text",
            "icon": "zoom-in-symbolic",
            "available": true
        },
        {
            "key": "a11yReduceMotion",
            "title": "Reduce Animations",
            "icon": "preferences-desktop-multitasking-symbolic",
            "available": true
        },
        {
            "key": "a11yScreenReader",
            "title": "Screen Reader",
            "icon": "audio-speakers-symbolic",
            "available": root.screenReaderAvailable
        }
    ]

    Process {
        running: true
        command: ["sh", "-c", "command -v orca >/dev/null && echo yes; true"]
        stdout: StdioCollector {
            onStreamFinished: root.screenReaderAvailable = text.trim() === "yes"
        }
    }

    Process {
        running: root.screenReaderRunning
        command: ["orca"]
    }
}
