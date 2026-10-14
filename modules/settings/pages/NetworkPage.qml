import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    signal navigate(string panel)

    function updateScanning() {
        NetworkService.setScanning(NetworkService.hasWifi && NetworkService.wifiEnabled, "settings.network");
    }
    Component.onCompleted: updateScanning()
    Component.onDestruction: NetworkService.setScanning(false, "settings.network")
    Connections {
        target: NetworkService
        function onWifiEnabledChanged() {
            root.updateScanning();
        }
    }

    function isSecure(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe && network.security !== WifiSecurityType.Unknown;
    }


    property string pendingNetwork: ""
    property string triedNetwork: ""
    property bool passwordRejected: false

    function activate(network) {
        if (network.connected) {
            NetworkService.disconnectWifi(network);
        } else if (network.known || !isSecure(network)) {
            NetworkService.connectWifi(network);
        } else {
            passwordRejected = false;
            pendingNetwork = network.name;
        }
    }

    function submitPassword() {
        const network = NetworkService.wifiNetworks.find(n => n.name === pendingNetwork);
        if (network) {
            triedNetwork = pendingNetwork;
            NetworkService.connectWifi(network, passwordEntry.text);
        }
        pendingNetwork = "";
    }

    Connections {
        target: NetworkService
        function onConnectionFailed(name, reason) {
            if (name === root.triedNetwork && reason === ConnectionFailReason.NoSecrets) {
                root.passwordRejected = true;
                root.pendingNetwork = name;
            }
        }
    }

    ModalDialog {
        open: root.pendingNetwork !== ""
        dialogWidth: Theme.dialogPromptWidth
        title: "Authentication required"
        description: "A password or encryption key is required to access the Wi-Fi network “" + root.pendingNetwork + "”."
        buttons: [
            {
                "id": "cancel",
                "text": "Cancel"
            },
            {
                "id": "connect",
                "text": "Connect",
                "primary": true
            }
        ]
        disabledButtons: passwordEntry.text.length < 8 ? ["connect"] : []

        onOpenChanged: {
            if (open) {
                passwordEntry.clear();
                passwordEntry.forceFocus();
            }
        }
        onCanceled: root.pendingNetwork = ""
        onButtonClicked: id => {
            if (id === "connect")
                root.submitPassword();
            else
                root.pendingNetwork = "";
        }

        Entry {
            id: passwordEntry
            Layout.alignment: Qt.AlignHCenter
            password: true
            placeholderText: "Password"
            onAccepted: if (text.length >= 8)
                root.submitPassword()
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.baseMargin
            Layout.bottomMargin: Theme.baseMargin
            visible: root.passwordRejected
            implicitHeight: errorText.implicitHeight + 2 * Theme.dialogLabelPadding
            radius: Theme.radiusButton
            color: Theme.dialogWarningBg

            Text {
                id: errorText
                anchors.fill: parent
                anchors.margins: Theme.dialogLabelPadding
                text: "The password was not accepted."
                color: Theme.warning
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightNormal
            }
        }
    }


    property bool hiddenOpen: false
    property string hiddenError: ""

    function submitHidden() {
        NetworkService.connectHidden(hiddenSsid.text, hiddenPsk.text);
        hiddenOpen = false;
    }

    Connections {
        target: NetworkService
        function onHiddenConnectFailed(ssid, message) {
            root.hiddenError = "Could not connect to “" + ssid + "”" + (message ? ": " + message : ".");
        }
    }

    ModalDialog {
        open: root.hiddenOpen
        dialogWidth: Theme.dialogPromptWidth
        title: "Connect to Hidden Network"
        description: "Enter the name of the network and, if it is protected, its password."
        buttons: [
            {
                "id": "cancel",
                "text": "Cancel"
            },
            {
                "id": "connect",
                "text": "Connect",
                "primary": true
            }
        ]
        disabledButtons: hiddenSsid.text === "" || (hiddenPsk.text !== "" && hiddenPsk.text.length < 8) ? ["connect"] : []

        onOpenChanged: {
            if (open) {
                hiddenSsid.clear();
                hiddenPsk.clear();
                hiddenSsid.forceFocus();
            }
        }
        onCanceled: root.hiddenOpen = false
        onButtonClicked: id => {
            if (id === "connect")
                root.submitHidden();
            else
                root.hiddenOpen = false;
        }

        Entry {
            id: hiddenSsid
            Layout.alignment: Qt.AlignHCenter
            placeholderText: "Network name"
        }
        Entry {
            id: hiddenPsk
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.baseMargin
            password: true
            placeholderText: "Password (optional)"
            onAccepted: if (hiddenSsid.text !== "" && (text === "" || text.length >= 8))
                root.submitHidden()
        }
    }

    PrefGroup {
        title: "Wi-Fi"
        visible: NetworkService.hasWifi || !NetworkService.wifiEnabled

        ActionRow {
            title: "Wi-Fi"
            subtitle: NetworkService.activeWifi ? "Connected to " + NetworkService.activeWifi.name : (NetworkService.wifiEnabled ? "Not connected" : "Off")
            ToggleSwitch {
                checked: NetworkService.wifiEnabled
                onToggled: NetworkService.setWifiEnabled(checked)
            }
        }
        ActionRow {
            visible: root.hiddenError !== ""
            title: root.hiddenError
            icon: "dialog-warning-symbolic"
            IconButton {
                flat: true
                icon: "window-close-symbolic"
                bg: Theme.cardBg
                onClicked: root.hiddenError = ""
            }
        }
        ActionRow {
            visible: NetworkService.wifiEnabled
            title: "Connect to Hidden Network…"
            icon: "network-wireless-symbolic"
            activatable: true
            onActivated: {
                root.hiddenError = "";
                root.hiddenOpen = true;
            }
        }
        ActionRow {
            title: "Saved Wi-Fi Networks"
            subtitle: NetworkService.savedWifi.length > 0 ? NetworkService.savedWifi.length + " saved" : ""
            icon: "document-save-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("network/saved")
        }
    }

    PrefGroup {
        title: "Visible Networks"
        visible: NetworkService.wifiEnabled

        ActionRow {
            visible: NetworkService.wifiNetworks.length === 0
            title: NetworkService.scanning ? "Searching for networks…" : "No networks found"
            Spinner {
                running: NetworkService.scanning
                color: Theme.windowFg
            }
        }

        Repeater {
            model: NetworkService.wifiNetworks

            ActionRow {
                required property var modelData
                title: modelData.name
                subtitle: modelData.state === ConnectionState.Connecting ? "Connecting…" : (modelData.connected ? "Connected" : (modelData.known ? "Saved" : ""))
                activatable: modelData.state !== ConnectionState.Connecting
                icon: NetworkService.signalLevel ? "network-wireless-signal-" + NetworkService.signalLevel(modelData.signalStrength) + "-symbolic" : "network-wireless-symbolic"
                onActivated: root.activate(modelData)

                Spinner {
                    running: modelData.state === ConnectionState.Connecting
                    color: Theme.windowFg
                }
                Icon {
                    visible: root.isSecure(modelData)
                    name: "network-wireless-encrypted-symbolic"
                    color: Theme.alpha(Theme.windowFg, 0.55)
                }
                IconButton {
                    visible: modelData.known
                    flat: true
                    icon: "user-trash-symbolic"
                    bg: Theme.cardBg
                    onClicked: NetworkService.forgetWifi(modelData)
                }
            }
        }
    }

    PrefGroup {
        title: "Wired"
        visible: NetworkService.hasEthernet

        ActionRow {
            title: "Ethernet"
            subtitle: !NetworkService.ethernetEnabled ? "Off" : (NetworkService.ethernetConnected ? "Connected" + (NetworkService.ethernetName ? " — " + NetworkService.ethernetName : "") : "Cable unplugged")
            icon: "network-wired-symbolic"
            ToggleSwitch {
                checked: NetworkService.ethernetEnabled
                onToggled: NetworkService.setEthernetEnabled(checked)
            }
        }
    }
}
