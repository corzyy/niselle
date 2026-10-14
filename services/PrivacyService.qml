pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var ignoredApps: ["quickshell", "niselle"]

    PwObjectTracker {
        objects: Pipewire.ready ? Pipewire.nodes.values : []
    }

    readonly property var _uses: {
        const out = [];
        if (!Pipewire.ready)
            return out;
        for (const l of Pipewire.links.values) {
            const src = l.source, dst = l.target;
            if (!src || !dst || !dst.isStream)
                continue;
            const sp = src.properties ?? ({}), dp = dst.properties ?? ({});
            const app = dp["application.name"] ?? dp["application.process.binary"] ?? dst.description ?? "";
            if (root.ignoredApps.indexOf(String(app).toLowerCase()) >= 0)
                continue;
            if (dp["stream.monitor"] === "true" || sp["stream.monitor"] === "true")
                continue;
            out.push({
                "app": app,
                "srcClass": sp["media.class"] ?? "",
                "srcRole": sp["media.role"] ?? "",
                "dstClass": dp["media.class"] ?? "",
                "stream": dst
            });
        }
        return out;
    }

    readonly property var cameraUsers: _uses.filter(u => u.srcClass === "Video/Source")
    readonly property var screenShares: _uses.filter(u => u.srcClass === "Stream/Output/Video")
    readonly property var micUsers: _uses.filter(u => u.srcClass === "Audio/Source" && u.dstClass === "Stream/Input/Audio")

    readonly property bool cameraInUse: cameraUsers.length > 0
    readonly property bool microphoneInUse: micUsers.length > 0
    readonly property bool screenSharing: screenShares.length > 0

    function _names(list) {
        return [...new Set(list.map(u => u.app).filter(a => a))].join(", ");
    }
    readonly property string cameraApps: _names(cameraUsers)
    readonly property string microphoneApps: _names(micUsers)
    readonly property string screenShareApps: _names(screenShares)

    property bool canStopSharing: false

    function stopSharing() {
        for (const u of screenShares)
            Quickshell.execDetached(["pw-cli", "destroy", String(u.stream.id)]);
    }


    property bool locationInUse: false

    Process {
        id: geoclue
        command: ["sh", "-c", 'busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.GeoClue2 2>/dev/null | grep -q true && busctl --system get-property org.freedesktop.GeoClue2 /org/freedesktop/GeoClue2/Manager org.freedesktop.GeoClue2.Manager InUse 2>/dev/null; true']
        stdout: StdioCollector {
            onStreamFinished: root.locationInUse = text.trim() === "b true"
        }
    }


    property int thunderboltPending: 0
    readonly property bool thunderboltAttention: thunderboltPending > 0

    Process {
        id: bolt
        command: ["sh", "-c", 'command -v boltctl >/dev/null || exit 0; busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.bolt 2>/dev/null | grep -q true && boltctl list 2>/dev/null; true']
        stdout: StdioCollector {
            onStreamFinished: root.thunderboltPending = (text.match(/status:\s+connected\b/g) ?? []).length
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'command -v pw-cli >/dev/null && echo yes; true']
        stdout: StdioCollector {
            onStreamFinished: root.canStopSharing = text.trim() === "yes"
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            geoclue.running = true;
            bolt.running = true;
        }
    }
}
