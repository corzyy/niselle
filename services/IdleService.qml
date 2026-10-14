pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

Singleton {
    id: root

    property bool caffeine: false

    function setCaffeine(on) {
        root.caffeine = on;
    }
    function toggleCaffeine() {
        root.caffeine = !root.caffeine;
    }

    readonly property bool lockActive: SettingsService.idleLockEnabled && !root.caffeine && !LockService.locked
    readonly property bool suspendActive: SettingsService.idleSuspendEnabled && !root.caffeine && SessionService.canSuspend

    IdleMonitor {
        enabled: root.lockActive
        timeout: Math.max(5, SettingsService.idleLockDelay)
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                LockService.lock();
        }
    }

    IdleMonitor {
        enabled: root.suspendActive
        timeout: Math.max(10, SettingsService.idleSuspendDelay)
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                SessionService.suspend();
        }
    }

    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=Niselle", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
    }

    property bool _sleepSignal: false
    Process {
        running: true
        command: ["stdbuf", "-oL", "dbus-monitor", "--system", "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("member=PrepareForSleep") >= 0)
                    root._sleepSignal = true;
                else if (root._sleepSignal && line.indexOf("boolean") >= 0) {
                    root._sleepSignal = false;
                    if (line.indexOf("true") >= 0 && SettingsService.lockBeforeSuspend)
                        LockService.lock();
                }
            }
        }
    }

    IpcHandler {
        target: "idle"

        function caffeine(state: string): string {
            if (state === "on")
                root.setCaffeine(true);
            else if (state === "off")
                root.setCaffeine(false);
            else
                root.toggleCaffeine();
            return root.caffeine ? "on" : "off";
        }
    }
}
