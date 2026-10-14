pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager


    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var wifiNetworks: {
        if (!wifiDevice || !wifiEnabled)
            return [];
        const best = {};
        for (const n of wifiDevice.networks.values) {
            const cur = best[n.name];
            if (!cur || n.connected || (!cur.connected && n.signalStrength > cur.signalStrength))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
    }
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) ?? null
    readonly property var connectingWifi: wifiNetworks.find(n => n.state === ConnectionState.Connecting) ?? null
    readonly property real signalStrength: activeWifi ? activeWifi.signalStrength : 0
    readonly property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false
    property bool _scanRequested: false
    onWifiDeviceChanged: _applyScanRequest()


    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool hasEthernet: wiredDevice !== null
    readonly property bool ethernetConnected: wiredDevice ? wiredDevice.connected : false
    readonly property string ethernetName: wiredDevice && wiredDevice.network ? wiredDevice.network.name : ""
    readonly property bool ethernetEnabled: wiredDevice ? wiredDevice.state === ConnectionState.Connected || wiredDevice.state === ConnectionState.Connecting : false


    readonly property int connectivity: Networking.connectivity
    readonly property bool online: ethernetConnected || activeWifi !== null

    readonly property string iconName: {
        if (!available)
            return "network-offline-symbolic";
        if (ethernetConnected)
            return "network-wired-symbolic";
        if (activeWifi)
            return "network-wireless-signal-" + signalLevel(signalStrength) + "-symbolic";
        if (connectingWifi)
            return "network-wireless-acquiring-symbolic";
        if (wifiEnabled && hasWifi)
            return "network-wireless-offline-symbolic";
        return hasEthernet ? "network-wired-disconnected-symbolic" : "network-offline-symbolic";
    }

    function signalLevel(strength) {
        const pct = strength * 100;
        if (pct > 80)
            return "excellent";
        if (pct > 55)
            return "good";
        if (pct > 30)
            return "ok";
        if (pct > 5)
            return "weak";
        return "none";
    }

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }
    function toggleWifi() {
        setWifiEnabled(!wifiEnabled);
    }
    property var _scanOwners: ({})
    function setScanning(on, owner) {
        const key = owner || "default";
        const next = Object.assign({}, _scanOwners);
        if (on)
            next[key] = true;
        else
            delete next[key];
        _scanOwners = next;
        _scanRequested = Object.keys(next).length > 0;
        _applyScanRequest();
    }
    function _applyScanRequest() {
        if (wifiDevice && wifiDevice.scannerEnabled !== _scanRequested)
            wifiDevice.scannerEnabled = _scanRequested;
    }

    function setEthernetEnabled(on) {
        if (!wiredDevice)
            return;
        ethernetCmd.command = ["nmcli", "device", on ? "connect" : "disconnect", wiredDevice.name];
        ethernetCmd.running = true;
    }
    function toggleEthernet() {
        setEthernetEnabled(!ethernetEnabled);
    }

    function connectWifi(network, psk) {
        if (!network)
            return;
        if (psk !== undefined && psk !== "")
            network.connectWithPsk(psk);
        else
            network.connect();
    }
    function disconnectWifi(network) {
        if (network)
            network.disconnect();
    }
    function forgetWifi(network) {
        if (network)
            network.forget();
    }

    signal connectionFailed(string name, int reason)


    property var savedWifi: []

    signal hiddenConnectFailed(string ssid, string message)

    function setSavedAutoconnect(profile, on) {
        if (!profile)
            return;
        savedModify.command = ["nmcli", "connection", "modify", "uuid", profile.uuid, "connection.autoconnect", on ? "yes" : "no"];
        savedModify.running = true;
    }
    function forgetSaved(profile) {
        if (!profile)
            return;
        savedModify.command = ["nmcli", "connection", "delete", "uuid", profile.uuid];
        savedModify.running = true;
    }
    function connectHidden(ssid, psk) {
        hiddenConnect.ssid = ssid;
        hiddenConnect.psk = psk;
        hiddenConnect.command = ["nmcli", "--ask", "device", "wifi", "connect", ssid, "hidden", "yes"];
        hiddenConnect.running = true;
    }
    function refreshSaved() {
        savedList.running = true;
    }

    Process {
        id: savedList
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const [name, uuid, type, autoconnect, active] = root._splitTerse(line);
                    if (type === "802-11-wireless")
                        list.push({
                            name,
                            uuid,
                            autoconnect: autoconnect === "yes",
                            active: active === "yes"
                        });
                }
                root.savedWifi = list.sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    Process {
        id: savedModify
        onExited: root.refreshSaved()
    }

    Process {
        id: hiddenConnect
        property string ssid: ""
        property string psk: ""
        stdinEnabled: true
        stderr: StdioCollector {
            id: hiddenErr
        }
        stdout: StdioCollector {
            id: hiddenOut
        }
        onStarted: if (psk !== "") {
            write(psk + "\n");
            psk = "";
        }
        onExited: (code, status) => {
            psk = "";
            if (code !== 0)
                root.hiddenConnectFailed(ssid, (hiddenErr.text || hiddenOut.text).trim());
            root.refreshSaved();
        }
    }


    property var vpnConnections: []
    readonly property bool hasVpn: vpnConnections.length > 0
    readonly property var activeVpn: vpnConnections.find(v => v.active) ?? null
    readonly property bool vpnActive: activeVpn !== null

    signal vpnFailed(string name, string message)

    function setVpn(vpn, on) {
        if (!vpn)
            return;
        vpnToggle.vpnName = vpn.name;
        vpnToggle.command = ["nmcli", "connection", on ? "up" : "down", "uuid", vpn.uuid];
        vpnToggle.running = true;
    }
    function toggleVpn(vpn) {
        setVpn(vpn, !vpn.active);
    }
    function refreshVpn() {
        vpnList.running = true;
    }

    function _splitTerse(line) {
        return line.split(/(?<!\\):/).map(s => s.replace(/\\(.)/g, "$1"));
    }

    Process {
        id: vpnList
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const [name, uuid, type, active] = root._splitTerse(line);
                    if (type === "vpn" || type === "wireguard")
                        list.push({
                            name,
                            uuid,
                            type,
                            active: active === "yes"
                        });
                }
                root.vpnConnections = list;
            }
        }
    }

    Process {
        id: vpnToggle
        property string vpnName: ""
        stderr: StdioCollector {
            id: vpnErr
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.vpnFailed(vpnName, vpnErr.text.trim());
            root.refreshVpn();
        }
    }


    property bool usbTetherConnected: false

    function refreshDevices() {
        deviceList.running = true;
    }

    Process {
        id: deviceList
        command: ["sh", "-c", 'nmcli -t -f DEVICE,TYPE,STATE device | while IFS=: read -r d t s; do case $t in ethernet) case $s in connected*) readlink -f "/sys/class/net/$d" | grep -q /usb && echo "usb connected";; esac;; esac; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.usbTetherConnected = lines.indexOf("usb connected") >= 0;
            }
        }
    }

    Process {
        id: ethernetCmd
        onExited: root.refreshDevices()
    }

    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: vpnDebounce.restart()
        }
    }

    Timer {
        id: vpnDebounce
        interval: 250
        onTriggered: {
            root.refreshVpn();
            root.refreshSaved();
            root.refreshDevices();
        }
    }

    Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root.connectionFailed(modelData.name, reason);
            }
        }
    }

    Component.onCompleted: {
        refreshVpn();
        refreshSaved();
        refreshDevices();
    }
}
