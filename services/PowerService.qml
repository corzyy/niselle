pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root


    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isPresent && battery.isLaptopBattery
    readonly property bool available: hasBattery || profilesAvailable

    readonly property real percentage: hasBattery ? battery.percentage * 100 : 0
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: hasBattery && battery.state === UPowerDeviceState.FullyCharged
    readonly property real timeToEmpty: hasBattery ? battery.timeToEmpty : 0
    readonly property real timeToFull: hasBattery ? battery.timeToFull : 0
    readonly property real timeRemaining: charging ? timeToFull : timeToEmpty
    readonly property string iconName: hasBattery ? battery.iconName : "battery-missing-symbolic"

    readonly property var peripherals: UPower.devices.values.filter(d => d.isPresent && !d.powerSupply && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "";
        const minutes = Math.round(seconds / 60);
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return h + ":" + (m < 10 ? "0" : "") + m;
    }


    property string backend: ""
    readonly property bool profilesAvailable: backend !== ""
    readonly property bool hasPerformanceProfile: backend === "tuned" ? true : (backend === "ppd" && PowerProfiles.hasPerformanceProfile)

    readonly property string ppdProfile: backend === "ppd" ? profileName(PowerProfiles.profile) : ""
    property string tunedActiveProfile: ""
    readonly property string tunedProfile: tunedToProfile(tunedActiveProfile)

    readonly property string profile: !profilesAvailable ? "" : backend === "tuned" ? tunedProfile : ppdProfile
    readonly property var profiles: !profilesAvailable ? [] : (hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"])
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

    readonly property var tunedPerformanceProfiles: ["throughput-performance", "latency-performance", "accelerator-performance", "network-latency", "network-throughput", "hpc-compute", "intel-sst", "virtual-host"]

    function tunedToProfile(name) {
        if (name === "powersave")
            return "power-saver";
        if (tunedPerformanceProfiles.indexOf(name) >= 0)
            return "performance";
        return "balanced";
    }
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

    Timer {
        running: root.backend === "tuned"
        interval: 5000
        repeat: true
        onTriggered: tunedActive.running = true
    }
}
