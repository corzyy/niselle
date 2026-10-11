import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Quick-Settings-Pille mit Status-Icons [quickSettings.js, GNOME-Mockup system-status-indicators]. Reihenfolge wie im Mockup:
// Datenschutz (Freigabe, Kamera, Mikrofon, Standort, orange), Nachtlicht, Thunderbolt, Netzwerk (USB, WLAN, VPN,
// Flugmodus), Bluetooth, Lautstärke, Akku (ohne Akku: Ausschalten).
Pill {
    id: root

    property color foreground: Theme.panelFg

    signal quickSettingsRequested

    fg: foreground
    inset: Theme.panelButtonBorder
    spacing: Theme.panelStatusIconSpacing

    onClicked: m => {
        if (!m || m.button === Qt.LeftButton)
            root.quickSettingsRequested();
    }

    component StatusIcon: Icon {
        property color tint: root.fg
        color: tint
        size: Theme.iconSize
        Layout.leftMargin: Theme.panelStatusIconMargin
        Layout.rightMargin: Theme.panelStatusIconMargin
    }

    // Datenschutz: nur Anzeigen, ohne Knopf zum Beenden (Aufnahme und Freigabe mit Knopf: CaptureIndicators)
    readonly property bool privacy: SettingsService.showPrivacyIndicators
    readonly property bool extras: SettingsService.showStatusIndicators

    StatusIcon {
        name: "applications-games-symbolic"
        visible: root.extras && SettingsService.gameMode
    }
    StatusIcon {
        name: "screen-shared-symbolic"
        tint: Theme.privacyIndicator
        visible: root.privacy && PrivacyService.screenSharing && !PrivacyService.canStopSharing
    }
    StatusIcon {
        name: "camera-web-symbolic"
        tint: Theme.privacyIndicator
        visible: root.privacy && PrivacyService.cameraInUse
    }
    StatusIcon {
        name: "audio-input-microphone-symbolic"
        tint: Theme.privacyIndicator
        visible: root.privacy && PrivacyService.microphoneInUse
    }
    StatusIcon {
        name: "location-services-active-symbolic"
        tint: Theme.privacyIndicator
        visible: root.privacy && PrivacyService.locationInUse
    }

    StatusIcon {
        name: "night-light-symbolic"
        visible: root.extras && SettingsService.nightLightActive
    }
    StatusIcon {
        name: "thunderbolt-symbolic"
        visible: root.extras && PrivacyService.thunderboltAttention
    }
    StatusIcon {
        name: "drive-harddisk-usb-symbolic"
        visible: root.extras && NetworkService.usbTetherConnected
    }
    StatusIcon {
        name: NetworkService.iconName
        visible: SettingsService.barShowNetwork && !!NetworkService.available && !(root.extras && SettingsService.airplaneMode)
    }
    StatusIcon {
        name: "network-vpn-symbolic"
        visible: root.extras && NetworkService.vpnActive
    }
    StatusIcon {
        name: "airplane-mode-symbolic"
        visible: root.extras && SettingsService.airplaneMode
    }
    StatusIcon {
        name: BluetoothService.iconName
        visible: SettingsService.barShowBluetooth && BluetoothService.available && BluetoothService.enabled && BluetoothService.connectedCount > 0 && !(root.extras && SettingsService.airplaneMode)
    }
    StatusIcon {
        id: volumeIcon
        name: AudioService.iconName
        visible: SettingsService.barShowVolume && AudioService.available
    }
    StatusIcon {
        name: Quickshell.shellPath("assets/icons/caffeine-symbolic.svg")
        visible: IdleService.caffeine
    }

    // Mausrad über dem Lautstärke-Icon ändert die Lautstärke [volume.js:454-465, slider.js:7]
    onWheeled: (dx, dy, x, y) => {
        if (!volumeIcon.visible)
            return;
        const tl = volumeIcon.mapToItem(root, 0, 0);
        const margin = Theme.panelStatusIconMargin;
        if (x < tl.x - margin || x > tl.x + volumeIcon.width + margin || y < tl.y - margin || y > tl.y + volumeIcon.height + margin)
            return;
        const d = dy !== 0 ? dy : -dx;
        if (d === 0)
            return;
        AudioService.setVolume(AudioService.volume + (d > 0 ? 0.02 : -0.02));
    }

    // Akku: Icon und optionale Prozentzahl ohne Abstand [_panel:150-152]
    RowLayout {
        visible: PowerService.hasBattery
        spacing: 0
        Layout.leftMargin: Theme.panelStatusIconMargin
        Layout.rightMargin: Theme.panelStatusIconMargin

        Icon {
            name: PowerService.iconName
            color: root.fg
            size: Theme.iconSize
        }
        PanelText {
            visible: SettingsService.showBatteryPercentage
            text: Math.round(PowerService.percentage) + " %"
            color: root.fg
        }
    }

    StatusIcon {
        name: "notifications-disabled-symbolic"
        visible: SettingsService.doNotDisturb
    }

    // Ohne Akku (Desktop): Ausschalten steht am Ende der Pille
    StatusIcon {
        name: "system-shutdown-symbolic"
        visible: !PowerService.hasBattery && SessionService.canPowerOff
    }
}
