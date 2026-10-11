pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Systemwerte für das Vitals-Element der Leiste: CPU-Last, Arbeitsspeicher, Swap, CPU-Temperatur, Netzwerkdurchsatz,
// Systemlast und Laufzeit. Gelesen wird alles aus /proc und /sys mit einem kurzen Prozess alle `interval` ms; das
// Abfragen läuft nur, solange `active` gesetzt ist (das Element ist in der Leiste platziert).
Singleton {
    id: root

    property bool active: false
    readonly property int interval: 2000

    // Prozent (0–100)
    property real cpu: 0
    property real memPercent: 0
    // Byte
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    // Grad Celsius, -1 ohne Sensor
    property real temperature: -1
    // Byte pro Sekunde (alle Schnittstellen außer lo)
    property real netDown: 0
    property real netUp: 0
    property var load: [0, 0, 0]
    property real uptime: 0

    property var _prevCpu: null
    property var _prevNet: null
    property double _prevTime: 0

    // Kompakte Größenangabe: 1.2 GB, 340 MB, 12 kB
    function formatBytes(b) {
        const units = ["B", "kB", "MB", "GB", "TB"];
        let v = b, i = 0;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1000;
            i++;
        }
        return (i === 0 || v >= 100 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }
    function formatRate(b) {
        return formatBytes(b) + "/s";
    }

    function _parse(text) {
        const sections = {};
        let cur = "";
        for (const line of text.split("\n")) {
            if (line.startsWith("@@")) {
                cur = line.slice(2);
                sections[cur] = [];
            } else if (cur !== "" && line !== "") {
                sections[cur].push(line);
            }
        }
        const now = Date.now();
        const dt = _prevTime > 0 ? (now - _prevTime) / 1000 : 0;
        _prevTime = now;

        // CPU: Anteil nicht-leerer Zeit zwischen zwei Messungen
        const st = (sections.stat?.[0] ?? "").trim().split(/\s+/).slice(1).map(Number);
        if (st.length >= 5) {
            const idle = st[3] + st[4];
            const total = st.reduce((a, b) => a + b, 0);
            if (_prevCpu && total > _prevCpu.total)
                cpu = Math.max(0, Math.min(100, 100 * (1 - (idle - _prevCpu.idle) / (total - _prevCpu.total))));
            _prevCpu = {
                "idle": idle,
                "total": total
            };
        }

        const mem = {};
        for (const line of sections.mem ?? []) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                mem[m[1]] = Number(m[2]) * 1024;
        }
        if (mem.MemTotal) {
            memTotal = mem.MemTotal;
            memUsed = mem.MemTotal - (mem.MemAvailable ?? 0);
            memPercent = 100 * memUsed / memTotal;
            swapTotal = mem.SwapTotal ?? 0;
            swapUsed = swapTotal - (mem.SwapFree ?? 0);
        }

        const la = (sections.load?.[0] ?? "").split(" ").slice(0, 3).map(Number);
        if (la.length === 3)
            load = la;
        uptime = Number(sections.up?.[0] ?? 0);

        let rx = 0, tx = 0;
        for (const line of sections.net ?? []) {
            const i = line.indexOf(":");
            if (i < 0 || line.slice(0, i).trim() === "lo")
                continue;
            const f = line.slice(i + 1).trim().split(/\s+/).map(Number);
            rx += f[0];
            tx += f[8];
        }
        if (_prevNet && dt > 0) {
            netDown = Math.max(0, (rx - _prevNet.rx) / dt);
            netUp = Math.max(0, (tx - _prevNet.tx) / dt);
        }
        _prevNet = {
            "rx": rx,
            "tx": tx
        };

        const t = Number(sections.temp?.[0] ?? NaN);
        temperature = isNaN(t) ? -1 : t / 1000;
    }

    Process {
        id: sampler
        command: ["sh", "-c", "echo @@stat; head -n1 /proc/stat; echo @@mem; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; echo @@load; cat /proc/loadavg; echo @@up; cut -d' ' -f1 /proc/uptime; echo @@net; tail -n +3 /proc/net/dev; echo @@temp; for d in /sys/class/hwmon/hwmon*; do case $(cat $d/name 2>/dev/null) in coretemp|k10temp|zenpower|cpu_thermal) cat $d/temp1_input; break;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!sampler.running)
            sampler.running = true
        onRunningChanged: if (!running) {
            root._prevCpu = null;
            root._prevNet = null;
            root._prevTime = 0;
        }
    }
}
