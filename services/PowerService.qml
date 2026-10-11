pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Energie: Akku über UPower, Energieprofile über power-profiles-daemon (via UPower-Modul).
// `percentage` ist 0..100 (Quickshell liefert 0..1, hier umgerechnet), Zeiten sind Sekunden.
// Die Geräte in `peripherals` sind rohe UPowerDevice-Objekte mit percentage 0..1.
Singleton {
    id: root

    // ───────── Akku ─────────

    readonly property var battery: UPower.displayDevice
    // Ein Laptop-Akku ist vorhanden (auf Desktops false)
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isPresent && battery.isLaptopBattery
    readonly property bool available: hasBattery || profilesAvailable

    readonly property real percentage: hasBattery ? battery.percentage * 100 : 0
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: hasBattery && battery.state === UPowerDeviceState.FullyCharged
    // Sekunden bis leer/voll; 0 = unbekannt
    readonly property real timeToEmpty: hasBattery ? battery.timeToEmpty : 0
    readonly property real timeToFull: hasBattery ? battery.timeToFull : 0
    // Restzeit der aktuellen Richtung (Laden → voll, Entladen → leer)
    readonly property real timeRemaining: charging ? timeToFull : timeToEmpty
    readonly property string iconName: hasBattery ? battery.iconName : "battery-missing-symbolic"

    // Andere Akkus mit Stromversorgung (z. B. Maus, Tastatur)
    readonly property var peripherals: UPower.devices.values.filter(d => d.isPresent && !d.powerSupply && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)

    // Zeit als "h:mm" wie in GNOME ("2:35 verbleibend")
    function formatTime(seconds) {
        if (!(seconds > 0))
            return "";
        const minutes = Math.round(seconds / 60);
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return h + ":" + (m < 10 ? "0" : "") + m;
    }

    // ───────── Energieprofile ─────────

    // Backend der Energieprofile: "ppd" (power-profiles-daemon), "tuned" oder "" (keines verfügbar)
    property string backend: ""
    readonly property bool profilesAvailable: backend !== ""
    // TuneD kennt immer alle drei Stufen; PPD nur mit Leistungsprofil
    readonly property bool hasPerformanceProfile: backend === "tuned" ? true : (backend === "ppd" && PowerProfiles.hasPerformanceProfile)

    // PPD: "power-saver" | "balanced" | "performance"
    readonly property string ppdProfile: backend === "ppd" ? profileName(PowerProfiles.profile) : ""
    // TuneD: aktives Profil (z. B. "throughput-performance"), auf dieselben drei Namen abgebildet
    property string tunedActiveProfile: ""
    readonly property string tunedProfile: tunedToProfile(tunedActiveProfile)

    // "power-saver" | "balanced" | "performance"; leer ohne Daemon
    readonly property string profile: !profilesAvailable ? "" : backend === "tuned" ? tunedProfile : ppdProfile
    // Verfügbare Profile in GNOME-Reihenfolge
    readonly property var profiles: !profilesAvailable ? [] : (hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"])
    // Grund, falls Leistung gedrosselt wird (z. B. "lap-detected"), sonst leer
    readonly property string degradationReason: backend === "ppd" && hasPerformanceProfile ? PerformanceDegradationReason.toString(PowerProfiles.degradationReason) : ""

    function profileName(p) {
        switch (p) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }

    // TuneD-Profile, die als "Leistung" zählen
    readonly property var tunedPerformanceProfiles: ["throughput-performance", "latency-performance", "accelerator-performance", "network-latency", "network-throughput", "hpc-compute", "intel-sst", "virtual-host"]

    function tunedToProfile(name) {
        if (name === "powersave")
            return "power-saver";
        if (tunedPerformanceProfiles.indexOf(name) >= 0)
            return "performance";
        return "balanced";
    }
    // GNOME-Name → TuneD-Profil
    function tunedTarget(name) {
        return name === "power-saver" ? "powersave" : name === "performance" ? "throughput-performance" : "balanced";
    }

    function setProfile(name) {
        if (!profilesAvailable || profiles.indexOf(name) < 0)
            return;
        if (backend === "tuned") {
            tunedSet.command = ["tuned-adm", "profile", tunedTarget(name)];
            tunedSet.running = true;
        } else {
            PowerProfiles.profile = name === "power-saver" ? PowerProfile.PowerSaver : name === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
        }
    }

    // Backend einmalig bestimmen: power-profiles-daemon zuerst, sonst TuneD
    Process {
        running: true
        command: ["sh", "-c", "if busctl --system list --no-legend 2>/dev/null | grep -qE '^(net\\.hadess\\.PowerProfiles|org\\.freedesktop\\.UPower\\.PowerProfiles) '; then echo ppd; elif busctl --system list --no-legend 2>/dev/null | grep -q '^com\\.redhat\\.tuned '; then echo tuned; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim();
                if (root.backend === "tuned")
                    tunedActive.running = true;
            }
        }
    }

    // Aktives TuneD-Profil lesen ("Current active profile: balanced")
    Process {
        id: tunedActive
        command: ["tuned-adm", "active"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Current active profile:\s*(\S+)/);
                root.tunedActiveProfile = m ? m[1] : "";
            }
        }
    }

    Process {
        id: tunedSet
        onExited: (code, status) => {
            if (root.backend === "tuned")
                tunedActive.running = true;
        }
    }

    // Änderungen von außen (z. B. tuned-adm in einem Terminal) nachlesen
    Timer {
        running: root.backend === "tuned"
        interval: 5000
        repeat: true
        onTriggered: tunedActive.running = true
    }
}
