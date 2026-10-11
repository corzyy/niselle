pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth über BlueZ (DBus): Adapter an/aus, Geräteliste, Verbinden/Trennen, Suche.
// Fehlt BlueZ oder ein Adapter, ist `available` false und alle Listen sind leer.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null

    readonly property bool enabled: adapter ? adapter.enabled : false
    // Adapter schaltet gerade um (BluetoothAdapterState.Enabling/Disabling)
    readonly property bool switching: adapter ? (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling) : false
    readonly property bool discovering: adapter ? adapter.discovering : false

    // Bekannte (gekoppelte) Geräte: verbundene zuerst, dann nach Name
    readonly property var pairedDevices: sorted(Bluetooth.devices.values.filter(d => (d.paired || d.bonded) && d.name))
    // Geräte in der Nähe, die noch nicht gekoppelt sind (während der Suche entdeckt)
    readonly property var nearbyDevices: sorted(Bluetooth.devices.values.filter(d => !d.paired && !d.bonded && d.name))
    // Alle Geräte inkl. der bei der Suche entdeckten
    readonly property var devices: sorted(Bluetooth.devices.values.filter(d => d.name))
    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)
    readonly property int connectedCount: connectedDevices.length

    // Suche: mehrere Oberflächen (Quick-Settings-Menü, Einstellungen) können sie gleichzeitig anfordern.
    // Die Suche läuft, solange mindestens eine sie braucht und der Adapter eingeschaltet ist.
    property var discoveryOwners: ({})
    readonly property bool discoveryRequested: Object.keys(discoveryOwners).length > 0

    // GNOME: bluetooth-active-symbolic (an) bzw. bluetooth-disabled-symbolic (aus)
    readonly property string iconName: enabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"

    // Verbinden/Trennen ist fehlgeschlagen oder abgeschlossen
    signal deviceConnected(var device)
    signal deviceDisconnected(var device)

    function sorted(list) {
        return list.slice().sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
    }

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }
    function toggle() {
        setEnabled(!enabled);
    }

    // Suche anfordern (owner = eindeutiger Schlüssel der Oberfläche) bzw. wieder freigeben.
    function requestDiscovery(owner) {
        if (!owner || discoveryOwners[owner])
            return;
        const next = Object.assign({}, discoveryOwners);
        next[owner] = true;
        discoveryOwners = next;
        applyDiscovery();
    }
    function releaseDiscovery(owner) {
        if (!owner || !discoveryOwners[owner])
            return;
        const next = Object.assign({}, discoveryOwners);
        delete next[owner];
        discoveryOwners = next;
        applyDiscovery();
    }
    function applyDiscovery() {
        if (adapter)
            adapter.discovering = adapter.enabled && Object.keys(discoveryOwners).length > 0;
    }

    function connectDevice(device) {
        if (device)
            device.connect();
    }
    function disconnectDevice(device) {
        if (device)
            device.disconnect();
    }
    function toggleDevice(device) {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else if (!device.paired && !device.bonded)
            device.pair();
        else
            device.connect();
    }
    function pair(device) {
        if (device)
            device.pair();
    }
    function forget(device) {
        if (device)
            device.forget();
    }

    // Adapter aus/an: Suche nur weiterlaufen lassen, solange er eingeschaltet ist
    onEnabledChanged: applyDiscovery()
    // Adapter wird von Quickshell erst nachträglich geliefert: bereits angeforderte Suche nachholen
    onAdapterChanged: applyDiscovery()

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (modelData.connected)
                    root.deviceConnected(modelData);
                else
                    root.deviceDisconnected(modelData);
            }
        }
    }
}
