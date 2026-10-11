pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Zustand der On-Screen-Anzeige [osdWindow.js]: Icon, optional Beschriftung und Pegel, nach `Theme.osdHideTimeout`
// wieder weg. Gezeigt wird nur auf dem primären Monitor (siehe Osd.qml).
//
// Auslöser sind Änderungen der Dienste, egal woher sie kommen (Medientasten über wpctl/brightnessctl, Hyprland-Binds,
// Schieberegler): Lautstärke/Stummschaltung, Mikrofon, Bildschirmhelligkeit, Tastatur-Hintergrundbeleuchtung.
// Beim Start und beim Wechsel des Standardgeräts wird nichts angezeigt. Caps/Num-Lock meldet Hyprland nicht als Ereignis;
// eine Tastenbindung ruft `quickshell ipc call osd locks` auf (siehe bin/niselle `niselle osd locks`), danach wird der Zustand gelesen.
Singleton {
    id: root

    // Anzeige soll sichtbar sein
    property bool shown: false
    property string iconName: ""
    // null: keine Beschriftung
    property var label: null
    // -1: kein Pegel
    property real level: -1
    property real maxLevel: 1

    // Erst nach dem Start reagieren: die Dienste liefern erst beim Verbinden ihre Anfangswerte
    property bool armed: false

    function show(icon, label, level, maxLevel) {
        if (!icon)
            return;
        root.iconName = icon;
        root.label = label ?? null;
        root.maxLevel = maxLevel ?? 1;
        root.level = level ?? -1;
        root.shown = true;
        hideTimer.restart();
    }
    function hide() {
        hideTimer.stop();
        root.shown = false;
    }

    Timer {
        id: hideTimer
        interval: Theme.osdHideTimeout
        onTriggered: root.shown = false
    }

    // Kurz warten, damit Dienste und Geräte ihre Anfangswerte gemeldet haben
    Timer {
        running: true
        interval: 1000
        onTriggered: {
            root.armed = true;
            root._syncAll();
            root.refreshLocks();
        }
    }

    function _changed(a, b) {
        return Math.abs(a - b) > 0.0005;
    }

    // ───────────── Lautstärke (Ausgabe) ─────────────

    property var _sink: null
    property real _volume: 0
    property bool _muted: false

    function _volumeLevel() {
        return AudioService.muted ? 0 : AudioService.volume;
    }
    function _syncSink() {
        root._sink = AudioService.sink;
        root._volume = AudioService.volume;
        root._muted = AudioService.muted;
    }
    function _onSinkState() {
        // Anderes Standardgerät: nur Basiswerte übernehmen
        if (!root.armed || AudioService.sink !== root._sink) {
            root._syncSink();
            return;
        }
        if (!AudioService.available)
            return;
        if (root._changed(AudioService.volume, root._volume) || AudioService.muted !== root._muted) {
            root._syncSink();
            root.show(AudioService.iconName, null, root._volumeLevel());
        }
    }

    Connections {
        target: AudioService
        function onSinkChanged() {
            root._syncSink();
        }
        function onVolumeChanged() {
            root._onSinkState();
        }
        function onMutedChanged() {
            root._onSinkState();
        }
    }

    // ───────────── Mikrofon ─────────────

    property var _source: null
    property real _sourceVolume: 0
    property bool _sourceMuted: false

    function _syncSource() {
        root._source = AudioService.source;
        root._sourceVolume = AudioService.sourceVolume;
        root._sourceMuted = AudioService.sourceMuted;
    }
    function _onSourceState() {
        if (!root.armed || AudioService.source !== root._source) {
            root._syncSource();
            return;
        }
        if (!AudioService.hasSource)
            return;
        if (root._changed(AudioService.sourceVolume, root._sourceVolume) || AudioService.sourceMuted !== root._sourceMuted) {
            root._syncSource();
            root.show(AudioService.sourceIconName, null, AudioService.sourceMuted ? 0 : AudioService.sourceVolume);
        }
    }

    Connections {
        target: AudioService
        function onSourceChanged() {
            root._syncSource();
        }
        function onSourceVolumeChanged() {
            root._onSourceState();
        }
        function onSourceMutedChanged() {
            root._onSourceState();
        }
    }

    // ───────────── Helligkeit ─────────────

    property string _brightnessDevice: ""
    property real _brightness: 0
    property string _kbdDevice: ""
    property real _kbdBrightness: 0

    Connections {
        target: BrightnessService
        function onBrightnessChanged() {
            const same = BrightnessService.device === root._brightnessDevice;
            const old = root._brightness;
            root._brightnessDevice = BrightnessService.device;
            root._brightness = BrightnessService.brightness;
            if (root.armed && same && BrightnessService.available && root._changed(old, BrightnessService.brightness))
                root.show(BrightnessService.iconName, null, BrightnessService.brightness);
        }
        function onDeviceChanged() {
            root._brightnessDevice = BrightnessService.device;
            root._brightness = BrightnessService.brightness;
        }
        function onKbdBrightnessChanged() {
            const same = BrightnessService.kbdDevice === root._kbdDevice;
            const old = root._kbdBrightness;
            root._kbdDevice = BrightnessService.kbdDevice;
            root._kbdBrightness = BrightnessService.kbdBrightness;
            if (root.armed && same && BrightnessService.kbdAvailable && root._changed(old, BrightnessService.kbdBrightness))
                root.show(BrightnessService.kbdIconName, null, BrightnessService.kbdBrightness);
        }
        function onKbdDeviceChanged() {
            root._kbdDevice = BrightnessService.kbdDevice;
            root._kbdBrightness = BrightnessService.kbdBrightness;
        }
    }

    function _syncAll() {
        root._syncSink();
        root._syncSource();
        root._brightnessDevice = BrightnessService.device;
        root._brightness = BrightnessService.brightness;
        root._kbdDevice = BrightnessService.kbdDevice;
        root._kbdBrightness = BrightnessService.kbdBrightness;
    }

    // ───────────── Caps Lock / Num Lock ─────────────

    // null: Zustand noch unbekannt
    property var _caps: null
    property var _num: null

    // Liest den Zustand der Haupttastatur aus Hyprland; meldet Änderungen, nicht den Anfangszustand
    function refreshLocks() {
        if (!locksQuery.running)
            locksQuery.running = true;
    }

    // Die Bindung feuert vor der Verarbeitung der Taste im Kompositor
    Timer {
        id: locksDelay
        interval: 50
        onTriggered: root.refreshLocks()
    }

    Process {
        id: locksQuery
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards;
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    if (!main)
                        return;
                    const caps = !!main.capsLock, num = !!main.numLock;
                    const first = root._caps === null;
                    const capsChanged = !first && caps !== root._caps;
                    const numChanged = !first && num !== root._num;
                    root._caps = caps;
                    root._num = num;
                    if (!root.armed)
                        return;
                    if (capsChanged)
                        root.show("input-keyboard-symbolic", caps ? qsTr("Feststelltaste an") : qsTr("Feststelltaste aus"));
                    else if (numChanged)
                        root.show("input-keyboard-symbolic", num ? qsTr("Num-Taste an") : qsTr("Num-Taste aus"));
                } catch (e) {}
            }
        }
    }

    // Steuerung von außen: quickshell ipc call osd locks | display <icon> <label> <level>
    IpcHandler {
        target: "osd"

        function locks(): void {
            locksDelay.restart();
        }
        // Entwicklungshilfe; level < 0: ohne Balken, label "-": ohne Beschriftung (leere Argumente kennt die CLI nicht)
        function display(icon: string, label: string, level: real, maxLevel: real): void {
            root.show(icon, label === "-" ? null : label, level, maxLevel > 0 ? maxLevel : 1);
        }
        function hide(): void {
            root.hide();
        }
    }
}
