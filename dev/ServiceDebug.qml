import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services

// Debug-Fenster der Services (NISELLE_DEBUG=<audio|network|bluetooth|power|brightness|media|notifications|apps|
// workspaces|session|settings>). Zeigt Eigenschaften des gewählten Dienstes und Testaktionen. Dienste sind
// Singletons und starten erst beim ersten Zugriff, es läuft also immer nur der gewählte Tab.
// Der Dump wird bei jeder Änderung auch ins Log geschrieben (NISELLE_DEBUG_LOG=1 für Headless-Tests).
FloatingWindow {
    id: win

    property string tab: Quickshell.env("NISELLE_DEBUG") || "settings"
    readonly property var tabs: ["audio", "network", "bluetooth", "power", "brightness", "media", "notifications", "apps", "workspaces", "session", "settings"]

    implicitWidth: 820
    implicitHeight: 640
    color: Theme.windowBg

    function names(list, prop) {
        return "[" + list.map(x => x[prop || "name"]).join(", ") + "]";
    }
    function lines(o) {
        return Object.keys(o).map(k => k + ": " + o[k]).join("\n");
    }

    // Jeder Zweig fasst nur den gewählten Dienst an
    readonly property string dump: {
        switch (tab) {
        case "audio":
            return lines({
                available: AudioService.available,
                volume: AudioService.volume.toFixed(2),
                muted: AudioService.muted,
                icon: AudioService.iconName,
                sink: AudioService.displayName(AudioService.sink),
                source: AudioService.displayName(AudioService.source),
                sourceVolume: AudioService.sourceVolume.toFixed(2),
                sourceMuted: AudioService.sourceMuted,
                sinks: names(AudioService.sinks, "description"),
                sources: names(AudioService.sources, "description")
            });
        case "network":
            return lines({
                available: NetworkService.available,
                icon: NetworkService.iconName,
                online: NetworkService.online,
                connectivity: NetworkService.connectivity,
                wifiDevice: NetworkService.wifiDevice ? NetworkService.wifiDevice.name : "-",
                wifiEnabled: NetworkService.wifiEnabled,
                activeWifi: NetworkService.activeWifi ? NetworkService.activeWifi.name : "-",
                signalStrength: NetworkService.signalStrength.toFixed(2),
                networks: NetworkService.wifiNetworks.map(n => n.name + " " + Math.round(n.signalStrength * 100) + "%" + (n.connected ? "*" : "")).join(", "),
                ethernet: NetworkService.hasEthernet ? (NetworkService.ethernetConnected ? "verbunden " + NetworkService.ethernetName : "getrennt") : "-",
                vpn: NetworkService.vpnConnections.map(v => v.name + (v.active ? "*" : "")).join(", ") || "-"
            });
        case "bluetooth":
            return lines({
                available: BluetoothService.available,
                enabled: BluetoothService.enabled,
                switching: BluetoothService.switching,
                discovering: BluetoothService.discovering,
                icon: BluetoothService.iconName,
                paired: BluetoothService.pairedDevices.map(d => d.name + (d.connected ? "*" : "")).join(", ") || "-",
                connected: BluetoothService.connectedCount
            });
        case "power":
            return lines({
                available: PowerService.available,
                hasBattery: PowerService.hasBattery,
                percentage: PowerService.percentage,
                onBattery: PowerService.onBattery,
                charging: PowerService.charging,
                remaining: PowerService.formatTime(PowerService.timeRemaining) || "-",
                icon: PowerService.iconName,
                profilesAvailable: PowerService.profilesAvailable,
                profile: PowerService.profile || "-",
                profiles: PowerService.profiles.join(", ") || "-",
                peripherals: PowerService.peripherals.map(d => d.model + " " + Math.round(d.percentage * 100)).join(", ") || "-"
            });
        case "brightness":
            return lines({
                available: BrightnessService.available,
                device: BrightnessService.device || "-",
                percent: BrightnessService.percent
            });
        case "media":
            return lines({
                available: MediaService.available,
                players: names(MediaService.players, "identity"),
                playing: MediaService.playing,
                title: MediaService.title,
                artist: MediaService.artist,
                artUrl: MediaService.artUrl,
                length: MediaService.length
            });
        case "notifications":
            return lines({
                available: NotificationService.available,
                doNotDisturb: NotificationService.doNotDisturb,
                count: NotificationService.count,
                banner: NotificationService.banner ? NotificationService.banner.summary : "-",
                groups: NotificationService.groups.map(g => g.appName + "(" + g.count + ")").join(", ") || "-"
            });
        case "apps":
            return lines({
                available: AppsService.available,
                apps: AppsService.apps.length,
                favorites: AppsService.favorites.map(e => e.name).join(", ") || "-",
                running: AppsService.runningApps.map(r => (r.entry ? r.entry.name : "?" + r.appId) + "×" + r.windows.length).join(", ") || "-",
                "search 'ter'": AppsService.search("ter", 5).map(e => e.name).join(", ") || "-"
            });
        case "workspaces":
            return lines({
                available: WorkspaceService.available,
                usingLua: WorkspaceService.usingLua,
                focusedMonitor: WorkspaceService.focusedMonitor ? WorkspaceService.focusedMonitor.name : "-",
                activeWindow: WorkspaceService.activeWindow ? WorkspaceService.activeWindow.title : "-",
                windows: WorkspaceService.windows.length,
                workspaces: Quickshell.screens.map(s => s.name + ": " + WorkspaceService.workspacesFor(s).map(w => w.id + (w.active ? "*" : "") + (w.empty ? "_" : "") + "[" + w.windows.length + "]").join(" ")).join("  |  ")
            });
        case "session":
            return lines({
                available: SessionService.available,
                canLock: SessionService.canLock,
                canSuspend: SessionService.canSuspend,
                canReboot: SessionService.canReboot,
                canPowerOff: SessionService.canPowerOff,
                sessionId: SessionService.sessionId,
                dryRun: SessionService.dryRun
            });
        default:
            return lines({
                available: SettingsService.available,
                loaded: SettingsService.loaded,
                darkMode: SettingsService.darkMode,
                nightLight: SettingsService.nightLight + (SettingsService.nightLightAvailable ? " (" + SettingsService.nightLightBackend + ")" : ""),
                airplaneMode: SettingsService.airplaneMode + (SettingsService.airplaneModeSynced ? " (rfkill)" : ""),
                doNotDisturb: SettingsService.doNotDisturb
            });
        }
    }

    // Testaktionen je Tab
    readonly property var actions: {
        switch (tab) {
        case "audio":
            return [["Stumm", () => AudioService.toggleMute()], ["+10%", () => AudioService.setVolume(AudioService.volume + 0.1)], ["−10%", () => AudioService.setVolume(AudioService.volume - 0.1)], ["Mic stumm", () => AudioService.toggleSourceMute()]];
        case "network":
            return [["WLAN an/aus", () => NetworkService.toggleWifi()], ["Suche", () => NetworkService.setScanning(!NetworkService.scanning)]];
        case "bluetooth":
            return [["An/aus", () => BluetoothService.toggle()], ["Suche", () => BluetoothService.discovering ? BluetoothService.releaseDiscovery("debug") : BluetoothService.requestDiscovery("debug")]];
        case "power":
            return [["Sparen", () => PowerService.setProfile("power-saver")], ["Ausgewogen", () => PowerService.setProfile("balanced")], ["Leistung", () => PowerService.setProfile("performance")]];
        case "brightness":
            return [["+10%", () => BrightnessService.setBrightness(BrightnessService.brightness + 0.1)], ["−10%", () => BrightnessService.setBrightness(BrightnessService.brightness - 0.1)]];
        case "media":
            return [["Play/Pause", () => MediaService.playPause()], ["Zurück", () => MediaService.previous()], ["Weiter", () => MediaService.next()]];
        case "notifications":
            return [["Test", () => Quickshell.execDetached(["notify-send", "-a", "Niselle", "Testmeldung", "Hallo von notify-send"])], ["Kritisch", () => Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Niselle", "Kritisch", "Bleibt stehen"])], ["DND", () => NotificationService.toggleDoNotDisturb()], ["Alle löschen", () => NotificationService.clearAll()], ["Banner weg", () => NotificationService.hideBanner()]];
        case "apps":
            return [["Favorit Terminal", () => AppsService.toggleFavorite(AppsService.search("terminal", 1)[0])]];
        case "workspaces":
            return [["Vorherige", () => WorkspaceService.switchRelative(-1)], ["Nächste", () => WorkspaceService.switchRelative(1)], ["Fläche neu fokussieren", () => WorkspaceService.switchTo(WorkspaceService.focusedWorkspace.id)], ["Aktives Fenster fokussieren", () => WorkspaceService.focusWindow(WorkspaceService.activeWindow)]];
        case "session":
            return [["Sperren", () => SessionService.lock()], ["Abmelden", () => SessionService.logout()], ["Standby", () => SessionService.suspend()], ["Neustart", () => SessionService.reboot()], ["Ausschalten", () => SessionService.powerOff()]];
        default:
            return [["Hell/Dunkel", () => SettingsService.toggleDarkMode()], ["Nachtlicht", () => SettingsService.toggleNightLight()], ["Flugmodus", () => SettingsService.toggleAirplaneMode()], ["Nicht stören", () => SettingsService.toggleDoNotDisturb()]];
        }
    }

    onDumpChanged: if (Quickshell.env("NISELLE_DEBUG_LOG") === "1")
        console.warn("[" + tab + "]\n" + dump)

    // NISELLE_DEBUG_RUN=<n> löst nach 1,5 s die n-te Testaktion aus (Headless-Tests)
    Timer {
        interval: 1500
        running: !!Quickshell.env("NISELLE_DEBUG_RUN")
        onTriggered: win.actions[parseInt(Quickshell.env("NISELLE_DEBUG_RUN"))][1]()
    }

    Component.onCompleted: {
        if (Quickshell.env("NISELLE_DEBUG_LOG") === "1")
            console.warn("[" + tab + "]\n" + dump);
        // Aktionen mit Folgen für das System dürfen im Debug-Fenster nichts ausführen
        SessionService.dryRun = tab === "session";
        Theme.dark = Quickshell.env("NISELLE_LIGHT") !== "1";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.cardPadding
        spacing: Theme.spacingLg

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Repeater {
                model: win.tabs
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool current: modelData === win.tab
                    implicitWidth: label.implicitWidth + Theme.spacingXl
                    implicitHeight: label.implicitHeight + Theme.spacingMd * 2
                    radius: Theme.radiusButton
                    color: current ? Theme.accentColor : Theme.cardBg

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.current ? Theme.accentFg : Theme.windowFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.tab = parent.modelData
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Repeater {
                model: win.actions
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: actionLabel.implicitWidth + Theme.spacingXl
                    implicitHeight: actionLabel.implicitHeight + Theme.spacingMd * 2
                    radius: Theme.radiusButton
                    color: Theme.cardShade

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: parent.modelData[0]
                        color: Theme.windowFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.modelData[1]()
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: win.dump
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            color: Theme.windowFg
            font.family: Theme.fontFamilyMono
            font.pointSize: Theme.fontSizeBase
        }
    }
}
