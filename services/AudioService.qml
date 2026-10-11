pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio über PipeWire: Lautstärke, Stummschaltung, Ausgabe-/Eingabegeräte, Standardgeräte.
// Lautstärke ist 0..1 (1 = 100 %). GNOME begrenzt ohne "Überverstärkung" auf 100 %.
Singleton {
    id: root

    // PipeWire läuft und hat ein Standard-Ausgabegerät
    readonly property bool available: Pipewire.ready && sink !== null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Ausgabe
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    // Eingabe (Mikrofon)
    readonly property real sourceVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool sourceMuted: source && source.audio ? source.audio.muted : false
    readonly property bool hasSource: source !== null

    // Alle Hardware-Ausgabe-/Eingabegeräte (keine App-Streams, keine Monitore)
    readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)

    // Symbolname wie in GNOME (volume.js): muted / low / medium / high
    readonly property string iconName: {
        if (!available || muted || volume <= 0)
            return "audio-volume-muted-symbolic";
        if (volume < 0.34)
            return "audio-volume-low-symbolic";
        if (volume < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }
    readonly property string sourceIconName: sourceMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"

    signal deviceChanged(var node, bool isSink)

    function displayName(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name;
    }

    function setVolume(v) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function setMuted(m) {
        if (sink && sink.audio)
            sink.audio.muted = m;
    }
    function toggleMute() {
        setMuted(!muted);
    }
    function setSourceVolume(v) {
        if (source && source.audio)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function setSourceMuted(m) {
        if (source && source.audio)
            source.audio.muted = m;
    }
    function toggleSourceMute() {
        setSourceMuted(!sourceMuted);
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    onSinkChanged: deviceChanged(sink, true)
    onSourceChanged: deviceChanged(source, false)

    // Ohne Tracker liefern Knoten keine Audio-Eigenschaften (volume/muted)
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks, root.sources).filter(n => n)
    }
}
