import QtQuick
import Quickshell
import Quickshell.Io

// Ein DDC/CI-Monitor (I2C-Bus) über ddcutil: Lesen per `getvcp 10`, Schreiben entprellt per `setvcp 10`.
// `value` (0..1) ist lokaler Zustand, damit der Slider beim Ziehen nicht auf langsame Monitor-Antworten wartet.
Scope {
    id: root

    property int bus: -1
    // DRM-Anschluss ohne "cardN-"-Präfix ("DP-1", …)
    property string connector: ""
    readonly property string label: connector !== "" ? connector : "Bus " + bus

    property int rawMax: 100
    property int rawValue: 0
    property real value: 0.5

    // Erst true, wenn ein getvcp erfolgreich war
    property bool available: false

    // Vom Entprell-Timer wartender Zielwert (0..rawMax)
    property int pendingRaw: -1

    function refresh() {
        if (bus <= 0)
            return;
        getter.command = ["ddcutil", "--bus", String(bus), "getvcp", "10", "--terse"];
        getter.running = false;
        getter.running = true;
    }

    function setValue(v) {
        const val = Math.max(0, Math.min(1, v));
        value = val;
        if (!available || bus <= 0)
            return;
        pendingRaw = Math.round(val * rawMax);
        debounce.restart();
    }

    function commit() {
        if (bus <= 0 || !available || pendingRaw < 0)
            return;
        const raw = pendingRaw;
        pendingRaw = -1;
        if (raw === rawValue)
            return;
        rawValue = raw;
        setter.command = ["ddcutil", "--bus", String(bus), "setvcp", "10", String(raw)];
        setter.running = false;
        setter.running = true;
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.commit()
    }

    Process {
        id: getter
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                // Keinen Wert überschreiben, den der Nutzer gerade setzt
                if (root.pendingRaw >= 0 || setter.running)
                    return;
                // "VCP 10 C <aktuell> <max>"
                const m = text.match(/VCP\s+[0-9A-Fa-f]+\s+C\s+(\d+)\s+(\d+)/);
                if (!m)
                    return;
                const max = Number(m[2]);
                root.rawMax = max > 0 ? max : 100;
                root.rawValue = Number(m[1]);
                root.value = root.rawValue / root.rawMax;
                root.available = true;
            }
        }
    }

    Process {
        id: setter
    }
}
