pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string deviceName: ""
    property string osName: ""
    property string osBuild: ""
    property string osType: ""
    property string osLogo: ""
    property string virtualization: ""
    property string kernel: ""
    property string shellVersion: "Niselle"
    property string windowing: ""
    property string hardwareModel: ""
    property string firmware: ""
    property string memory: ""
    property string processor: ""
    property string graphics: ""
    property string disk: ""

    function reload() {
        reader.running = true;
    }

    function setDeviceName(name) {
        const n = name.trim();
        if (n === "" || n === root.deviceName)
            return;
        renamer.command = ["hostnamectl", "set-hostname", "--pretty", n];
        renamer.running = true;
    }

    function _apply(map) {
        deviceName = map.device ?? "";
        osName = map.os ?? "";
        osBuild = map.build ?? "";
        osLogo = map.logo ?? "";
        osType = map.bits ? map.bits + "-bit" : "";
        virtualization = map.virt ?? "";
        kernel = map.kernel ?? "";
        hardwareModel = map.model ?? "";
        firmware = map.firmware ?? "";
        memory = map.mem ?? "";
        processor = map.cpu ?? "";
        graphics = map.gpu ?? "";
        disk = map.disk ?? "";
        windowing = map.session ? (map.session === "wayland" ? "Wayland" : map.session === "x11" ? "X11" : map.session) : "";
    }

    Process {
        id: reader
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            pretty=$(hostnamectl --pretty 2>/dev/null); [ -n "$pretty" ] || pretty=$(hostname)
            echo "device=$pretty"
            echo "os=\${PRETTY_NAME:-$NAME}"
            echo "logo=\${LOGO}"
            echo "build=\${BUILD_ID}"
            echo "bits=$(getconf LONG_BIT)"
            v=$(systemd-detect-virt 2>/dev/null); [ "$v" = none ] && v=""
            echo "virt=$(echo "$v" | tr a-z A-Z)"
            echo "kernel=$(uname -sr)"
            d=/sys/class/dmi/id
            echo "model=$(cat $d/sys_vendor 2>/dev/null) $(cat $d/product_name 2>/dev/null)"
            echo "firmware=$(cat $d/bios_version 2>/dev/null)"
            kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
            echo "mem=$(awk -v k=$kb 'BEGIN{printf "%.1f GiB", k/1048576}')"
            echo "cpu=$(awk -F: '/model name/ {gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo | sed 's/([RTM]*)//g;s/  */ /g')"
            echo "gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/^[^:]*: *//;s/^[^:]*: *//;s/ (rev .*)//')"
            b=$(lsblk -dbno SIZE,TYPE 2>/dev/null | awk '$2=="disk" {s+=$1} END {print s}')
            echo "disk=$(awk -v b=\${b:-0} 'BEGIN{ if (b>=1e12) printf "%.1f TB", b/1e12; else printf "%.1f GB", b/1e9 }')"
            echo "session=$XDG_SESSION_TYPE"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        map[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root._apply(map);
            }
        }
    }

    Process {
        id: renamer
        onExited: root.reload()
    }
}
