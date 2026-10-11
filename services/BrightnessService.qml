pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bildschirmhelligkeit über brightnessctl (nutzt logind SetBrightness, wenn kein Schreibzugriff auf sysfs besteht).
// `brightness` ist 0..1. Änderungen von außen (Tasten, andere Programme) kommen über inotify auf
// /sys/class/backlight/<gerät>/actual_brightness, es gibt kein Polling.
// Ohne Backlight-Gerät (Desktop) werden externe Monitore per DDC/CI über ddcutil gesteuert (DdcDisplay.qml, alle gemeinsam);
// ddcutil braucht Schreibzugriff auf /dev/i2c-*.
// Dazu die Tastatur-Hintergrundbeleuchtung (LED-Klasse, Gerät *kbd_backlight) nach demselben Muster.
Singleton {
    id: root

    // Ein Backlight-Gerät wurde gefunden und brightnessctl lieferte Werte
    readonly property bool available: device !== "" || ddcAvailable

    property string device: ""
    property int current: 0
    property int max: 0

    // DDC/CI-Monitore (nur wenn es kein Backlight gibt)
    property var ddcDisplays: []
    readonly property bool ddcAvailable: device === "" && ddcDisplays.length > 0
    readonly property real ddcValue: {
        let sum = 0, n = 0;
        for (const d of ddcDisplays) {
            if (d.available) {
                sum += d.value;
                n++;
            }
        }
        return n > 0 ? sum / n : 0.5;
    }

    readonly property real brightness: device === "" ? (ddcAvailable ? ddcValue : 0) : (max > 0 ? current / max : 0)
    readonly property int percent: Math.round(brightness * 100)
    readonly property string iconName: "display-brightness-symbolic"

    // Neuer Wert 0..1; mehrere schnelle Aufrufe (Slider) werden zusammengefasst
    function setBrightness(value) {
        if (!available)
            return;
        const v = Math.max(0, Math.min(1, value));
        if (ddcAvailable) {
            for (const d of ddcDisplays)
                d.setValue(v);
            return;
        }
        // Optimistisch anzeigen, damit der Slider nicht zurückspringt
        root.current = Math.round(v * root.max);
        setter.pending = Math.round(v * 100);
    }
    function refresh() {
        query.running = true;
    }

    Component {
        id: ddcComp
        DdcDisplay {}
    }

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._ddcDetected(text)
        }
    }

    // Jeder "Display N"-Block nennt seinen I2C-Bus; "Invalid display" hat keinen solchen Kopf und wird übersprungen
    function _ddcDetected(text) {
        const found = [];
        let cur = null;
        for (const line of text.split("\n")) {
            if (/^\s*Display\s+\d+\s*$/.test(line)) {
                cur = {
                    "bus": -1,
                    "connector": ""
                };
                found.push(cur);
                continue;
            }
            if (/^\s*Invalid display/.test(line)) {
                cur = null;
                continue;
            }
            if (!cur)
                continue;
            const bm = line.match(/\/dev\/i2c-(\d+)/);
            if (bm)
                cur.bus = parseInt(bm[1]);
            const cm = line.match(/DRM connector:\s*(\S+)/);
            if (cm)
                cur.connector = cm[1].replace(/^card\d+-/, "");
        }
        const usable = found.filter((e, i) => e.bus > 0 && found.findIndex(o => o.bus === e.bus) === i);
        for (const d of root.ddcDisplays)
            d.destroy();
        root.ddcDisplays = usable.map(e => ddcComp.createObject(root, e));
        for (const d of root.ddcDisplays)
            d.refresh();
    }

    // Kein Backlight: stattdessen DDC/CI-Monitore suchen (einmalig, ddcutil ist langsam)
    function _noBacklight() {
        root.device = "";
        if (!ddcDetect.running && root.ddcDisplays.length === 0)
            ddcDetect.running = true;
    }

    Process {
        id: query
        command: ["brightnessctl", "--machine-readable", "--class=backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Gerät,Klasse,Aktuell,Prozent,Max
                const f = text.trim().split(",");
                if (f.length < 5) {
                    root._noBacklight();
                    return;
                }
                root.device = f[0];
                root.current = parseInt(f[2]);
                root.max = parseInt(f[4]);
            }
        }
        // Kein Backlight / brightnessctl fehlt
        onExited: (code, status) => {
            if (code !== 0)
                root._noBacklight();
        }
    }

    Process {
        id: setter
        property int pending: -1
        // Prozentwert setzen; läuft schon ein Aufruf, wird danach nur der letzte Wert angewandt
        onPendingChanged: root._applyPending()
        onExited: (code, status) => root._applyPending()
    }

    function _applyPending() {
        if (setter.running || setter.pending < 0)
            return;
        setter.command = ["brightnessctl", "--quiet", "--class=backlight", "set", setter.pending + "%"];
        setter.pending = -1;
        setter.running = true;
    }

    FileView {
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/actual_brightness" : ""
        watchChanges: true
        onFileChanged: root.refresh()
    }

    // Tastatur-Hintergrundbeleuchtung: ein LED-Gerät mit "kbd_backlight" im Namen
    readonly property bool kbdAvailable: kbdDevice !== ""
    property string kbdDevice: ""
    property int kbdCurrent: 0
    property int kbdMax: 0
    readonly property real kbdBrightness: kbdMax > 0 ? kbdCurrent / kbdMax : 0
    readonly property string kbdIconName: "keyboard-brightness-symbolic"

    function refreshKbd() {
        kbdQuery.running = true;
    }

    Process {
        id: kbdQuery
        command: ["brightnessctl", "--machine-readable", "--list", "--class=leds"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Gerät,Klasse,Aktuell,Prozent,Max
                const f = text.split("\n").map(l => l.split(",")).find(c => c.length >= 5 && c[0].includes("kbd_backlight"));
                if (!f) {
                    root.kbdDevice = "";
                    return;
                }
                root.kbdDevice = f[0];
                root.kbdCurrent = parseInt(f[2]);
                root.kbdMax = parseInt(f[4]);
            }
        }
        // brightnessctl fehlt: kein Gerät
        onExited: (code, status) => {
            if (code !== 0)
                root.kbdDevice = "";
        }
    }

    // Änderungen durch Tasten (Firmware: brightness_hw_changed) oder Programme (brightness)
    FileView {
        path: root.kbdDevice !== "" ? "/sys/class/leds/" + root.kbdDevice + "/brightness" : ""
        watchChanges: true
        onFileChanged: root.refreshKbd()
    }
    FileView {
        path: root.kbdDevice !== "" ? "/sys/class/leds/" + root.kbdDevice + "/brightness_hw_changed" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: root.refreshKbd()
    }

    Component.onCompleted: {
        refresh();
        refreshKbd();
    }
}
