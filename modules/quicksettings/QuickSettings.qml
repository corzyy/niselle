import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services
import qs.modules.datemenu

// Quick-Settings-Popover (QuickSettingsMenu) [quickSettings.js, system.js, volume.js, brightness.js, network.js,
// bluetooth.js, powerProfiles.js, nightLight.js, darkMode.js, rfkill.js]: hängt unter dem rechten Panel-Bereich,
// 6px Abstand zu Panel und Bildschirmrand [boxpointer.js:515-566]. Von oben: Kopfzeile, Lautstärke, Helligkeit,
// Kachelraster (2 Spalten). Untermenüs liegen wie in der Shell auf einer eigenen Ebene über dem Raster, das
// Raster darunter wird abgedunkelt; im Layout reserviert ein Platzhalter ihre Höhe.
//
// Kacheln ohne Dienst fehlen und die übrigen rücken nach (NISELLE_QS_DEMO=1 zeigt alle, nur zum Prüfen des Layouts).
Scope {
    id: root

    // Panel-Fenster, an dem das Popover hängt
    required property var barWindow

    readonly property alias open: popup.open
    // Name des offenen Untermenüs: "power", "output", "network", "bluetooth", "profile", "performance", "keyboard", "background" oder ""
    property string openMenu: ""

    readonly property bool demo: Quickshell.env("NISELLE_QS_DEMO") === "1"

    property var now: new Date()

    // Bearbeitungsansicht (Kacheln hinzufügen, entfernen, umsortieren) statt der normalen Ansicht
    property bool editing: false

    // Hintergrundprogramme [backgroundApps.js]: StatusNotifier-Einträge der Leiste (passive entfallen).
    // Über den Schließen-Knopf ausgeblendete Einträge stehen in hiddenBackground.
    property var hiddenBackground: ({})
    readonly property var backgroundItems: SystemTray.items.values.filter(i => i.status !== Status.Passive && !root.hiddenBackground[i.id])
    readonly property int backgroundCount: backgroundItems.length
    readonly property string backgroundTitle: backgroundCount === 0 ? "Keine Hintergrundprogramme" : backgroundCount === 1 ? "1 Hintergrundprogramm" : backgroundCount + " Hintergrundprogramme"

    function hideBackground(id) {
        const next = Object.assign({}, root.hiddenBackground);
        next[id] = true;
        root.hiddenBackground = next;
    }

    // Alle Kacheln; Reihenfolge und Auswahl in SettingsService.quickToggles
    readonly property var tileCatalog: [
        {
            "id": "network",
            "title": "Netzwerk",
            "icon": "network-wireless-symbolic",
            "category": "connectivity"
        },
        {
            "id": "bluetooth",
            "title": "Bluetooth",
            "icon": "bluetooth-active-symbolic",
            "category": "connectivity"
        },
        {
            "id": "vpn",
            "title": "VPN",
            "icon": "network-vpn-symbolic",
            "category": "connectivity"
        },
        {
            "id": "airplane",
            "title": "Flugmodus",
            "icon": "airplane-mode-symbolic",
            "category": "connectivity"
        },
        {
            "id": "profile",
            "title": "Energiemodus",
            "icon": "power-profile-balanced-symbolic",
            "category": "device"
        },
        {
            "id": "performance",
            "title": "Leistung",
            "icon": "power-profile-performance-symbolic",
            "category": "device"
        },
        {
            "id": "gamemode",
            "title": "Gamemode",
            "icon": "applications-games-symbolic",
            "category": "device"
        },
        {
            "id": "keyboard",
            "title": "Tastatur",
            "icon": "input-keyboard-symbolic",
            "category": "device"
        },
        {
            "id": "nightLight",
            "title": "Nachtlicht",
            "icon": "night-light-symbolic",
            "category": "appearance"
        },
        {
            "id": "dark",
            "title": "Dunkler Stil",
            "icon": Quickshell.shellPath("assets/icons/dark-mode-symbolic.svg"),
            "category": "appearance"
        },
        {
            "id": "dnd",
            "title": "Nicht stören",
            "icon": "notifications-disabled-symbolic",
            "category": "appearance"
        },
        {
            "id": "caffeine",
            "title": "Koffein",
            "icon": Quickshell.shellPath("assets/icons/caffeine-symbolic.svg"),
            "category": "device"
        },
        {
            "id": "bigyahoo",
            "title": "BigYahoo",
            "icon": Quickshell.shellPath("assets/icons/israel-flag.svg"),
            "symbolic": false,
            "category": "appearance"
        }
    ]
    // Kachel auf diesem System nutzbar (Dienst vorhanden)
    readonly property var tileAvailable: ({
            "network": networkTile.available,
            "bluetooth": bluetoothTile.available,
            "vpn": vpnTile.available,
            "airplane": airplaneTile.available,
            "profile": profileTile.available,
            "performance": performanceTile.available,
            "gamemode": gamemodeTile.available,
            "keyboard": keyboardTile.available,
            "nightLight": nightLightTile.available,
            "dark": darkTile.available,
            "dnd": dndTile.available,
            "caffeine": caffeineTile.available,
            "bigyahoo": bigYahooTile.available
        })

    // Zeitpunkt, an dem das Popover zuletzt geschlossen wurde (ms)
    property double closedAt: 0

    // Ein Klick auf die Pille schließt zuerst per Fokus-Grab; der folgende Klick darf nicht sofort wieder öffnen
    function toggle() {
        if (!popup.open && Date.now() - closedAt < 200)
            return;
        editing = false;
        popup.toggle();
    }
    function close() {
        popup.close();
    }
    function toggleMenu(name) {
        openMenu = openMenu === name ? "" : name;
    }

    // Fenster nicht pro Animationsbild skalieren: beim Öffnen sofort die Endhöhe reservieren,
    // erst nach dem vollständigen Schließen aller Untermenüs wieder freigeben
    readonly property var allMenus: [powerMenu, outputMenu, brightnessMenu, networkMenu, bluetoothMenu, profileMenu, performanceMenu, keyboardMenu, backgroundMenu]
    readonly property bool anyMenuShown: allMenus.some(m => m.shown)
    readonly property real menuExtra: allMenus.reduce((sum, m) => sum + (m.shown ? m.height + Theme.spacingLg * m.reveal : 0), 0)
    property real reservedHeight: 0

    onOpenMenuChanged: {
        if (openMenu === "")
            return;
        const menu = ({
                "power": powerMenu,
                "output": outputMenu,
                "brightness": brightnessMenu,
                "network": networkMenu,
                "bluetooth": bluetoothMenu,
                "profile": profileMenu,
                "performance": performanceMenu,
                "keyboard": keyboardMenu,
                "background": backgroundMenu
            })[openMenu];
        if (!menu)
            return;
        const base = stack.implicitHeight - menuExtra;
        const target = base + menu.naturalHeight + Theme.spacingLg;
        // Nie höher als der Platz unter der Leiste: die Liste unten schrumpft, sobald ein Untermenü aufgeht
        const room = (root.barWindow.screen ? root.barWindow.screen.height : 800) - root.barWindow.height - 2 * popup.margin;
        reservedHeight = Math.min(room, Math.max(reservedHeight, target + 2 * (Theme.quickSettingsPadding + Theme.popoverBorderWidth)));
    }
    onAnyMenuShownChanged: {
        if (!anyMenuShown)
            reservedHeight = 0;
    }

    // Steuerung von außen (Tastenkürzel, Tests): quickshell ipc call quicksettings.<Monitorname> toggle|open|close|menu <name>
    IpcHandler {
        target: "quicksettings." + (root.barWindow.screen ? root.barWindow.screen.name : "")

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            popup.open = true;
        }
        function close(): void {
            root.close();
        }
        function menu(name: string): void {
            popup.open = true;
            root.openMenu = name;
        }
        function edit(on: bool): void {
            popup.open = true;
            root.openMenu = "";
            root.editing = on;
        }
        function cancel(): void {
            root.pendingNetwork = "";
            root.pendingSession = "";
        }
        // Dialoge ohne passendes Netz/Ereignis prüfen: "password" oder "reboot" | "poweroff" | "logout"
        function dialog(kind: string): void {
            if (kind === "password")
                root.pendingNetwork = "Testnetz";
            else
                root.askSession(kind);
        }
    }

    // ───────── Hilfen ─────────

    readonly property var profileInfo: ({
            "performance": {
                "name": "Leistung",
                "icon": "power-profile-performance-symbolic"
            },
            "balanced": {
                "name": "Ausbalanciert",
                "icon": "power-profile-balanced-symbolic"
            },
            "power-saver": {
                "name": "Energiesparen",
                "icon": "power-profile-power-saver-symbolic"
            }
        })

    // Zuletzt gewähltes Nicht-Standard-Profil (Kachel schaltet zwischen diesem und "balanced")
    property string lastProfile: ""

    Connections {
        target: PowerService
        function onProfileChanged() {
            if (PowerService.profile !== "" && PowerService.profile !== "balanced")
                root.lastProfile = PowerService.profile;
        }
    }

    function sinkIcon(node) {
        const name = node && node.properties ? node.properties["device.icon-name"] : undefined;
        if (name && Quickshell.iconPath(name + "-symbolic", true) !== "")
            return name + "-symbolic";
        return "audio-speakers-symbolic";
    }

    function isSecure(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe && network.security !== WifiSecurityType.Unknown;
    }

    function openSettingsPanel(panel) {
        SessionService.openSettings(panel);
        popup.close();
    }

    // ───────── WLAN: Anmeldung ─────────

    property string pendingNetwork: ""
    property string triedNetwork: ""
    property bool passwordRejected: false

    function connectNetwork(network) {
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

    // Fehlendes oder falsches Passwort: Dialog erneut mit Hinweis
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
        id: passwordDialog

        screen: root.barWindow.screen
        open: root.pendingNetwork !== ""
        dialogWidth: Theme.dialogPromptWidth
        title: "Anmeldung für WLAN erforderlich"
        description: "Für den Zugriff auf das WLAN-Netzwerk „" + root.pendingNetwork + "“ ist ein Passwort oder ein Verschlüsselungsschlüssel nötig."
        buttons: [
            {
                "id": "cancel",
                "text": "Abbrechen"
            },
            {
                "id": "connect",
                "text": "Verbinden",
                "primary": true
            }
        ]
        // WPA-Passphrasen haben mindestens 8 Zeichen
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
            placeholderText: "Passwort"
            onAccepted: if (text.length >= 8)
                root.submitPassword()
        }
        // .prompt-dialog-error-label: Warnfarbe auf getöntem Grund
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
                text: "Das Passwort wurde nicht akzeptiert."
                color: Theme.warning
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightNormal
            }
        }
    }

    // ───────── Ein/Aus: Rückfrage ─────────

    // "reboot", "poweroff", "logout" oder ""
    property string pendingSession: ""
    property int sessionCountdown: 60

    readonly property var sessionInfo: ({
            "reboot": {
                "title": "Neustart",
                "button": "Neustart",
                "text": "Das System wird in %1 Sekunden automatisch neu gestartet."
            },
            "poweroff": {
                "title": "Ausschalten",
                "button": "Ausschalten",
                "text": "Das System wird in %1 Sekunden automatisch ausgeschaltet."
            },
            "logout": {
                "title": "Abmelden",
                "button": "Abmelden",
                "text": "Sie werden in %1 Sekunden automatisch abgemeldet."
            }
        })

    function runSession(action) {
        if (action === "reboot")
            SessionService.reboot();
        else if (action === "poweroff")
            SessionService.powerOff();
        else if (action === "logout")
            SessionService.logout();
    }

    function askSession(action) {
        sessionCountdown = 60;
        pendingSession = action;
        popup.close();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pendingSession !== ""
        onTriggered: {
            root.sessionCountdown -= 1;
            if (root.sessionCountdown <= 0) {
                const action = root.pendingSession;
                root.pendingSession = "";
                root.runSession(action);
            }
        }
    }

    ModalDialog {
        id: sessionDialog

        readonly property var info: root.sessionInfo[root.pendingSession] ?? ({
                "title": "",
                "button": "",
                "text": ""
            })

        screen: root.barWindow.screen
        open: root.pendingSession !== ""
        dialogWidth: 24 * 14.667 // .end-session-dialog width: 24em [_dialogs.scss:48]
        title: info.title
        description: info.text.replace("%1", root.sessionCountdown)
        buttons: [
            {
                "id": "cancel",
                "text": "Abbrechen"
            },
            {
                "id": "confirm",
                "text": info.button,
                "primary": true
            }
        ]

        onCanceled: root.pendingSession = ""
        onButtonClicked: id => {
            const action = root.pendingSession;
            root.pendingSession = "";
            if (id === "confirm")
                root.runSession(action);
        }
    }

    // ───────── Popover ─────────

    PopupMenu {
        id: popup

        anchor.window: root.barWindow
        // Rechte obere Ecke der Karte: 6px unter dem Panel und 6px vom Bildschirmrand
        anchor.rect.x: root.barWindow.width - Theme.popoverRise + margin - 1
        anchor.rect.y: root.barWindow.height + Theme.popoverRise - margin - 1
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.None

        // Klick außerhalb schließt über den Fokus-Grab. NISELLE_QS_NOGRAB=1 schaltet ihn ab (Screenshots per IPC ohne Klick).
        grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"
        openDuration: Theme.durationControlCenter
        cornerRadius: Theme.radiusQuickSettings
        contentPadding: Theme.quickSettingsPadding
        minWidth: 0
        // Mit Benachrichtigungen wächst/schrumpft die Karte beim Auf-/Zuklappen einer Gruppe, beim Eintreffen und
        // Verwerfen: das Fenster bekommt sofort die größtmögliche Höhe, sonst ändert der Compositor es in jedem Bild
        // (das ruckelte). Die Karte selbst bleibt oben bündig.
        reserveHeight: Math.max(root.reservedHeight, messages.visible ? (root.barWindow.screen ? root.barWindow.screen.height : 800) - root.barWindow.height - 2 * popup.margin : 0)

        onOpenChanged: {
            if (open) {
                root.now = new Date();
            } else {
                root.openMenu = "";
                root.editing = false;
                root.closedAt = Date.now();
            }
        }

        Item {
            id: body

            Layout.preferredWidth: Theme.quickSettingsWidth
            Layout.preferredHeight: root.editing ? editor.height : stack.implicitHeight

            QuickEditor {
                id: editor

                visible: root.editing
                width: parent.width
                height: Math.min(640, (root.barWindow.screen ? root.barWindow.screen.height : 800) - 160)
                catalog: root.tileCatalog
                available: root.tileAvailable
                onCloseRequested: root.editing = false
            }

            ColumnLayout {
                id: stack

                visible: !root.editing
                width: parent.width
                spacing: Theme.spacingLg

                SystemRow {
                    opacity: Theme.enter(popup.progress, 0, 12)
                    transform: Translate { y: (1 - Theme.enter(popup.progress, 0, 12)) * Theme.enterRise }
                    Layout.fillWidth: true
                    forceBattery: root.demo
                    forceScreenshot: root.demo
                    onEditRequested: {
                        root.openMenu = "";
                        root.editing = true;
                    }
                    onSettingsRequested: {
                        popup.close();
                        SettingsWindowService.show();
                    }
                    onPowerMenuRequested: root.toggleMenu("power")
                    onScreenshotRequested: {
                        if (ScreenRecordingService.recording) {
                            ScreenRecordingService.stop();
                            return;
                        }
                        popup.close();
                        if (SessionService.canScreenshot)
                            SessionService.screenshot();
                        else
                            ScreenRecordingService.start();
                    }
                }

                Item {
                    id: powerSlot
                    visible: powerMenu.shown
                    Layout.fillWidth: true
                    Layout.preferredHeight: powerMenu.height
                    // Der Layout-Abstand wächst mit der Höhe, statt beim Öffnen zu springen
                    Layout.topMargin: -Theme.spacingLg * (1 - powerMenu.reveal)
                }

                QuickSlider {
                    id: volume

                    opacity: Theme.enter(popup.progress, 1, 12)
                    transform: Translate { y: (1 - Theme.enter(popup.progress, 1, 12)) * Theme.enterRise }
                    visible: AudioService.available || root.demo
                    Layout.fillWidth: true
                    icon: AudioService.iconName
                    iconReactive: true
                    value: AudioService.muted ? 0 : AudioService.volume
                    menuEnabled: AudioService.sinks.length > 1
                    menuOpen: root.openMenu === "output"
                    // Unter einer Raste stumm, sonst Stummschaltung aufheben [volume.js:170-191]
                    onMoved: v => {
                        AudioService.setVolume(v);
                        AudioService.setMuted(v <= 0);
                    }
                    onIconClicked: {
                        // Stumm bei Lautstärke 0: auf 25 % setzen [volume.js:43,111-117]
                        if (AudioService.muted && AudioService.volume <= 0)
                            AudioService.setVolume(0.25);
                        AudioService.toggleMute();
                    }
                    onMenuClicked: root.toggleMenu("output")
                }

                Item {
                    id: outputSlot
                    visible: outputMenu.shown
                    Layout.fillWidth: true
                    Layout.preferredHeight: outputMenu.height
                    // Der Layout-Abstand wächst mit der Höhe, statt beim Öffnen zu springen
                    Layout.topMargin: -Theme.spacingLg * (1 - outputMenu.reveal)
                }

                QuickSlider {
                    opacity: Theme.enter(popup.progress, 2, 12)
                    transform: Translate { y: (1 - Theme.enter(popup.progress, 2, 12)) * Theme.enterRise }
                    visible: BrightnessService.available || root.demo
                    Layout.fillWidth: true
                    icon: BrightnessService.iconName
                    value: BrightnessService.brightness
                    menuEnabled: BrightnessService.ddcDisplays.length > 1
                    menuOpen: root.openMenu === "brightness"
                    onMoved: v => BrightnessService.setBrightness(v)
                    onMenuClicked: root.toggleMenu("brightness")
                }

                Item {
                    id: brightnessSlot
                    visible: brightnessMenu.shown
                    Layout.fillWidth: true
                    Layout.preferredHeight: brightnessMenu.height
                    // Der Layout-Abstand wächst mit der Höhe, statt beim Öffnen zu springen
                    Layout.topMargin: -Theme.spacingLg * (1 - brightnessMenu.reveal)
                }

                // Kachelraster: Position nach Reihenfolge der sichtbaren Kacheln, Untermenüs schieben die
                // folgenden Reihen nach unten [quickSettings.js:288-327, 502-522]
                Item {
                    id: grid

                    readonly property real cellHeight: Theme.quickToggleHeight
                    readonly property real gap: Theme.spacingLg
                    readonly property var tileById: ({
                "network": networkTile,
                "bluetooth": bluetoothTile,
                "profile": profileTile,
                "performance": performanceTile,
                "gamemode": gamemodeTile,
                "nightLight": nightLightTile,
                "dark": darkTile,
                "vpn": vpnTile,
                "airplane": airplaneTile,
                "dnd": dndTile,
                "caffeine": caffeineTile,
                "keyboard": keyboardTile,
                "bigyahoo": bigYahooTile
            })
            // Kacheln in der eingestellten Reihenfolge
            readonly property var tiles: SettingsService.quickToggles.map(id => tileById[id]).filter(t => !!t)
                    readonly property var menuTiles: [[networkMenu, networkTile], [bluetoothMenu, bluetoothTile], [profileMenu, profileTile], [performanceMenu, performanceTile], [keyboardMenu, keyboardTile]]
                    readonly property int visibleCount: tiles.filter(t => t.shown).length

                    Layout.fillWidth: true
                    Layout.preferredHeight: rowTop(Math.ceil(visibleCount / 2)) - gap
                    visible: visibleCount > 0

                    function slotOf(tile) {
                        let n = 0;
                        for (const t of tiles) {
                            if (t === tile)
                                break;
                            if (t.shown)
                                n++;
                        }
                        return n;
                    }
                    function rowOf(tile) {
                        return Math.floor(slotOf(tile) / 2);
                    }
                    // Höhe, die Untermenüs oberhalb von Reihe r belegen (Abstand + Menühöhe)
                    function extraBefore(r) {
                        let extra = 0;
                        for (const [menu, tile] of menuTiles) {
                            if (tile.shown && menu.shown && rowOf(tile) < r)
                                extra += menu.height + gap * menu.reveal;
                        }
                        return extra;
                    }
                    function rowTop(r) {
                        return r * (cellHeight + gap) + extraBefore(r);
                    }
                    function xOf(tile) {
                        return (slotOf(tile) % 2) * (Theme.quickToggleWidth + gap);
                    }
                    function yOf(tile) {
                        return rowTop(rowOf(tile));
                    }
                    function menuY(tile) {
                        return yOf(tile) + cellHeight + gap;
                    }

                    // Netzwerk: WLAN und Kabelgebunden in einer Kachel [network.js:1380-1420, 1800-1900]
                    ToggleButton {
                        id: networkTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(networkTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(networkTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || (NetworkService.available && (NetworkService.hasWifi || NetworkService.hasEthernet))
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("network") >= 0
                        visible: shown
                        x: grid.xOf(networkTile)
                        y: grid.yOf(networkTile)
                        enabled: NetworkService.hasWifi ? NetworkService.wifiHardwareEnabled : true
                        title: "Netzwerk"
                        subtitle: NetworkService.connectingWifi ? NetworkService.connectingWifi.name
                            : NetworkService.activeWifi ? NetworkService.activeWifi.name
                            : NetworkService.ethernetConnected ? (NetworkService.ethernetName || "Verbunden")
                            : NetworkService.hasWifi && !NetworkService.wifiEnabled ? "Aus"
                            : "Getrennt"
                        icon: NetworkService.iconName
                        checked: (NetworkService.hasWifi && NetworkService.wifiEnabled) || NetworkService.ethernetConnected
                        hasMenu: true
                        onClicked: NetworkService.hasWifi ? NetworkService.toggleWifi() : NetworkService.toggleEthernet()
                        onMenuClicked: root.toggleMenu("network")
                    }

                    // Bluetooth [bluetooth.js:272-425]
                    ToggleButton {
                        id: bluetoothTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(bluetoothTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(bluetoothTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || BluetoothService.available
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("bluetooth") >= 0
                        visible: shown
                        x: grid.xOf(bluetoothTile)
                        y: grid.yOf(bluetoothTile)
                        title: "Bluetooth"
                        subtitle: BluetoothService.connectedCount > 1 ? BluetoothService.connectedCount + " verbunden" : (BluetoothService.connectedCount === 1 ? BluetoothService.connectedDevices[0].name : "")
                        icon: BluetoothService.iconName
                        checked: BluetoothService.enabled
                        hasMenu: true
                        onClicked: BluetoothService.toggle()
                        onMenuClicked: root.toggleMenu("bluetooth")
                    }

                    // Energiemodus [powerProfiles.js:28-130]
                    ToggleButton {
                        id: profileTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(profileTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(profileTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || PowerService.profilesAvailable
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("profile") >= 0
                        visible: shown
                        x: grid.xOf(profileTile)
                        y: grid.yOf(profileTile)
                        title: "Energiemodus"
                        subtitle: (root.profileInfo[PowerService.profile] ?? root.profileInfo["balanced"]).name
                        icon: (root.profileInfo[PowerService.profile] ?? root.profileInfo["balanced"]).icon
                        checked: PowerService.profile !== "" && PowerService.profile !== "balanced"
                        hasMenu: PowerService.profiles.length > 2
                        onClicked: {
                            if (checked)
                                PowerService.setProfile("balanced");
                            else
                                PowerService.setProfile(root.lastProfile !== "" ? root.lastProfile : (PowerService.hasPerformanceProfile ? "performance" : "power-saver"));
                        }
                        onMenuClicked: root.toggleMenu("profile")
                    }

                    // Leistung: reine Auswahl des Energieprofils über ein Menü (Leistung/Ausbalanciert/Energiesparen)
                    ToggleButton {
                        id: performanceTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(performanceTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(performanceTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || PowerService.profilesAvailable
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("performance") >= 0
                        visible: shown
                        x: grid.xOf(performanceTile)
                        y: grid.yOf(performanceTile)
                        title: "Leistung"
                        subtitle: (root.profileInfo[PowerService.profile] ?? root.profileInfo["balanced"]).name
                        icon: "power-profile-performance-symbolic"
                        checked: PowerService.profile === "performance"
                        onClicked: root.toggleMenu("performance")
                    }

                    // Gamemode: Blur und Animationen systemweit aus – Hyprland über GameModeService,
                    // die Shell über Theme.gameMode (animationen und Schatten)
                    ToggleButton {
                        id: gamemodeTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(gamemodeTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(gamemodeTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || GameModeService.available
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("gamemode") >= 0
                        visible: shown
                        x: grid.xOf(gamemodeTile)
                        y: grid.yOf(gamemodeTile)
                        title: "Gamemode"
                        subtitle: SettingsService.gameMode ? "Blur und Animationen aus" : ""
                        icon: "applications-games-symbolic"
                        checked: SettingsService.gameMode
                        onClicked: SettingsService.toggleGameMode()
                    }

                    // Nachtlicht [nightLight.js:14-35]
                    ToggleButton {
                        id: nightLightTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(nightLightTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(nightLightTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || SettingsService.nightLightAvailable
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("nightLight") >= 0
                        visible: shown
                        x: grid.xOf(nightLightTile)
                        y: grid.yOf(nightLightTile)
                        title: "Nachtlicht"
                        icon: "night-light-symbolic"
                        checked: SettingsService.nightLight
                        onClicked: SettingsService.toggleNightLight()
                    }

                    // Dunkler Stil [darkMode.js:10-40]
                    ToggleButton {
                        id: darkTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(darkTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(darkTile), 12)) * Theme.enterRise }
                        readonly property bool available: true
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("dark") >= 0
                        visible: shown
                        x: grid.xOf(darkTile)
                        y: grid.yOf(darkTile)
                        title: "Dunkler Stil"
                        icon: Quickshell.shellPath("assets/icons/dark-mode-symbolic.svg")
                        checked: SettingsService.darkMode
                        onClicked: SettingsService.toggleDarkMode()
                    }

                    // VPN: schaltet die aktive Verbindung ab, sonst die erste gespeicherte an (Auswahl im Netzwerk-Menü)
                    ToggleButton {
                        id: vpnTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(vpnTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(vpnTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || (NetworkService.available && NetworkService.hasVpn)
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("vpn") >= 0
                        visible: shown
                        x: grid.xOf(vpnTile)
                        y: grid.yOf(vpnTile)
                        title: "VPN"
                        subtitle: NetworkService.activeVpn ? NetworkService.activeVpn.name : ""
                        icon: "network-vpn-symbolic"
                        checked: NetworkService.vpnActive
                        onClicked: {
                            const vpn = NetworkService.activeVpn ?? NetworkService.vpnConnections[0];
                            if (vpn)
                                NetworkService.toggleVpn(vpn);
                        }
                    }

                    // Flugmodus [rfkill.js:92-117]
                    ToggleButton {
                        id: airplaneTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(airplaneTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(airplaneTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || SettingsService.airplaneModeSynced
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("airplane") >= 0
                        visible: shown
                        x: grid.xOf(airplaneTile)
                        y: grid.yOf(airplaneTile)
                        title: "Flugmodus"
                        icon: "airplane-mode-symbolic"
                        checked: SettingsService.airplaneMode
                        onClicked: SettingsService.toggleAirplaneMode()
                    }

                    // Nicht stören
                    ToggleButton {
                        id: dndTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(dndTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(dndTile), 12)) * Theme.enterRise }
                        readonly property bool available: true
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("dnd") >= 0
                        visible: shown
                        x: grid.xOf(dndTile)
                        y: grid.yOf(dndTile)
                        title: "Nicht stören"
                        icon: "notifications-disabled-symbolic"
                        checked: SettingsService.doNotDisturb
                        onClicked: SettingsService.toggleDoNotDisturb()
                    }

                    // Koffein: kein automatisches Sperren/Standby (IdleService)
                    ToggleButton {
                        id: caffeineTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(caffeineTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(caffeineTile), 12)) * Theme.enterRise }
                        readonly property bool available: true
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("caffeine") >= 0
                        visible: shown
                        x: grid.xOf(caffeineTile)
                        y: grid.yOf(caffeineTile)
                        title: "Koffein"
                        icon: Quickshell.shellPath("assets/icons/caffeine-symbolic.svg")
                        checked: IdleService.caffeine
                        onClicked: IdleService.toggleCaffeine()
                    }

                    // BigYahoo: ersetzt jedes Symbol in der Shell durch die israelische Flagge (siehe components/Icon.qml)
                    ToggleButton {
                        id: bigYahooTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(bigYahooTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(bigYahooTile), 12)) * Theme.enterRise }
                        readonly property bool available: true
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("bigyahoo") >= 0
                        visible: shown
                        x: grid.xOf(bigYahooTile)
                        y: grid.yOf(bigYahooTile)
                        title: "BigYahoo"
                        icon: Quickshell.shellPath("assets/icons/israel-flag.svg")
                        iconSymbolic: false
                        checked: SettingsService.bigYahoo
                        onClicked: SettingsService.toggleBigYahoo()
                    }

                    // Tastaturlayout: Klick wechselt zum nächsten, Pfeil listet alle
                    ToggleButton {
                        id: keyboardTile
                        opacity: Theme.enter(popup.progress, 3 + grid.slotOf(keyboardTile), 12)
                        transform: Translate { y: (1 - Theme.enter(popup.progress, 3 + grid.slotOf(keyboardTile), 12)) * Theme.enterRise }
                        readonly property bool available: root.demo || KeyboardService.multiple
                        readonly property bool shown: available && SettingsService.quickToggles.indexOf("keyboard") >= 0
                        visible: shown
                        x: grid.xOf(keyboardTile)
                        y: grid.yOf(keyboardTile)
                        title: "Tastatur"
                        subtitle: KeyboardService.shortName
                        icon: "input-keyboard-symbolic"
                        hasMenu: true
                        onClicked: KeyboardService.setLayout((KeyboardService.activeIndex + 1) % Math.max(1, KeyboardService.layouts.length))
                        onMenuClicked: root.toggleMenu("keyboard")
                    }
                }

                // Hintergrundprogramme [backgroundApps.js:121-212, _quick-settings.scss:244-272]: flache Zeile
                // über die volle Breite unter dem Kachelraster; öffnet das Untermenü der laufenden Anwendungen.
                BackgroundAppsToggle {
                    opacity: Theme.enter(popup.progress, 10, 12)
                    transform: Translate { y: (1 - Theme.enter(popup.progress, 10, 12)) * Theme.enterRise }
                    id: backgroundToggle
                    visible: root.demo || root.backgroundCount > 0 || root.openMenu === "background"
                    title: root.backgroundTitle
                    checked: root.openMenu === "background"
                    onClicked: root.toggleMenu("background")
                }

                Item {
                    id: backgroundSlot
                    visible: backgroundMenu.shown
                    Layout.fillWidth: true
                    Layout.preferredHeight: backgroundMenu.height
                    // Der Layout-Abstand wächst mit der Höhe, statt beim Öffnen zu springen
                    Layout.topMargin: -Theme.spacingLg * (1 - backgroundMenu.reveal)
                }

                // Medien und Benachrichtigungen: dieselbe Liste wie im Datumsmenü (Gruppen auf- und zuklappen,
                // einzeln verwerfen, „Leeren“), nur ohne eigenen Nicht-stören-Schalter – dafür gibt es die Kachel.
                // Ohne Inhalt fehlt der Abschnitt ganz.
                MessageList {
                    id: messages

                    opacity: Theme.enter(popup.progress, 11, 12)
                    transform: Translate { y: (1 - Theme.enter(popup.progress, 11, 12)) * Theme.enterRise }
                    // Höhe der übrigen Abschnitte (ohne Liste); die Liste füllt den Rest bis zum Bildschirmrand
                    readonly property real othersHeight: {
                        let h = 0;
                        for (const c of stack.visibleChildren) {
                            if (c !== messages)
                                h += c.height + stack.spacing;
                        }
                        return h;
                    }
                    readonly property real screenHeight: root.barWindow.screen ? root.barWindow.screen.height : 800

                    Layout.fillWidth: true
                    visible: !empty
                    embedded: true
                    maxHeight: Math.max(Theme.quickSettingsMinListHeight, Math.min(Theme.quickSettingsMaxListHeight, screenHeight - root.barWindow.height - 2 * (Theme.quickSettingsPadding + Theme.popoverBorderWidth + Theme.spacingLg) - othersHeight))
                    active: popup.open
                    now: root.now
                    onCloseRequested: popup.close()
                }
            }

            // Abdunklung unter den Untermenüs [quickSettings.js:579-606]; deckt die ganze Karte samt Rand
            Rectangle {
                anchors.fill: parent
                anchors.margins: -(Theme.quickSettingsPadding + Theme.popoverBorderWidth)
                radius: Theme.radiusQuickSettings - Theme.popoverBorderWidth
                color: "black"
                opacity: root.openMenu !== "" ? Theme.quickSettingsDim : 0
                visible: opacity > 0
                z: 1

                Behavior on opacity {
                    enabled: !Theme.gameMode
                    NumberAnimation {
                        duration: Theme.durationQuickSettings
                        easing.type: Theme.easeOutQuad
                    }
                }
            }

            // ───────── Untermenüs (Ebene über der Abdunklung) ─────────

            // Ein/Aus [system.js:150-213]
            QuickMenu {
                id: powerMenu
                z: 2
                width: body.width
                y: stack.y + powerSlot.y
                open: root.openMenu === "power"
                onCloseRequested: root.openMenu = ""
                headerIcon: "system-shutdown-symbolic"
                headerTitle: "Ausschalten"

                PopupMenuItem {
                    visible: SessionService.canLock
                    text: "Sperren"
                    onActivated: {
                        popup.close();
                        SessionService.lock();
                    }
                }
                PopupMenuItem {
                    visible: SessionService.canSuspend
                    text: "Standby"
                    onActivated: {
                        popup.close();
                        SessionService.suspend();
                    }
                }
                PopupMenuItem {
                    visible: SessionService.canReboot
                    text: "Neustart …"
                    onActivated: root.askSession("reboot")
                }
                PopupMenuItem {
                    visible: SessionService.canPowerOff
                    text: "Ausschalten …"
                    onActivated: root.askSession("poweroff")
                }
                Separator {
                    visible: SessionService.canLogout && (SessionService.canLock || SessionService.canSuspend || SessionService.canReboot || SessionService.canPowerOff)
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }
                PopupMenuItem {
                    visible: SessionService.canLogout
                    text: "Abmelden …"
                    onActivated: root.askSession("logout")
                }
            }

            // Tonausgabe [volume.js:53-72, 285-330]
            QuickMenu {
                id: outputMenu
                z: 2
                width: body.width
                y: stack.y + outputSlot.y
                open: root.openMenu === "output"
                onCloseRequested: root.openMenu = ""
                headerIcon: "audio-headphones-symbolic"
                headerTitle: "Tonausgabe"

                Repeater {
                    model: AudioService.sinks

                    PopupMenuItem {
                        required property var modelData
                        Layout.fillWidth: true
                        ornamented: true
                        ornamentChecked: modelData === AudioService.sink
                        icon: root.sinkIcon(modelData)
                        text: AudioService.displayName(modelData)
                        onActivated: AudioService.setDefaultSink(modelData)
                    }
                }
                Separator {
                    visible: SessionService.canOpenSettings
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }
                PopupMenuItem {
                    visible: SessionService.canOpenSettings
                    text: "Klangeinstellungen"
                    closeOnActivate: false
                    onActivated: root.openSettingsPanel("sound")
                }
            }

            // Helligkeit je Monitor (DDC/CI)
            QuickMenu {
                id: brightnessMenu
                z: 2
                width: body.width
                y: stack.y + brightnessSlot.y
                open: root.openMenu === "brightness"
                onCloseRequested: root.openMenu = ""
                headerIcon: BrightnessService.iconName
                headerTitle: "Helligkeit"

                Repeater {
                    model: BrightnessService.ddcDisplays

                    ColumnLayout {
                        id: monitorItem
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.basePadding
                        spacing: Theme.basePadding

                        Text {
                            text: monitorItem.modelData.label
                            color: Theme.transparentize(Theme.fgColor, 0.4)
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                        }
                        QuickSlider {
                            Layout.fillWidth: true
                            icon: BrightnessService.iconName
                            value: monitorItem.modelData.value
                            onMoved: v => monitorItem.modelData.setValue(v)
                        }
                    }
                }
            }

            // Netzwerk: WLAN-Netze, Kabelverbindung und VPN in einem Menü [network.js:1000-1075, 1800-1900]
            QuickMenu {
                id: networkMenu
                z: 2
                width: body.width
                x: 0
                y: stack.y + grid.y + grid.menuY(networkTile)
                open: root.openMenu === "network"
                onCloseRequested: root.openMenu = ""
                headerIcon: NetworkService.hasWifi ? "network-wireless-symbolic" : "network-wired-symbolic"
                headerTitle: "Netzwerk"
                headerActive: networkTile.checked
                // Suche nur, solange das Menü offen ist [network.js:1855-1875]
                onOpenChanged: {
                    NetworkService.setScanning(open && NetworkService.wifiEnabled, "quicksettings.network");
                    if (open)
                        NetworkService.refreshVpn();
                }

                headerSuffix: Spinner {
                    running: NetworkService.connectingWifi !== null
                }

                // ───────── WLAN ─────────
                MenuSectionLabel {
                    visible: NetworkService.hasWifi
                    text: "WLAN"
                }

                // WLAN an/aus
                PopupMenuItem {
                    id: wifiToggleItem
                    visible: NetworkService.hasWifi
                    Layout.fillWidth: true
                    closeOnActivate: false
                    icon: NetworkService.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
                    text: NetworkService.wifiEnabled ? "WLAN an" : "WLAN aus"
                    onActivated: NetworkService.toggleWifi()

                    Icon {
                        visible: NetworkService.wifiEnabled
                        name: "object-select-symbolic"
                        color: wifiToggleItem.fg
                    }
                }

                Repeater {
                    model: NetworkService.wifiNetworks

                    PopupMenuItem {
                        id: networkItem
                        required property var modelData
                        Layout.fillWidth: true
                        icon: "network-wireless-signal-" + NetworkService.signalLevel(modelData.signalStrength) + "-symbolic"
                        badgeIcon: root.isSecure(modelData) ? "network-wireless-encrypted-symbolic" : ""
                        text: modelData.name
                        onActivated: root.connectNetwork(modelData)

                        Icon {
                            visible: modelData.connected
                            name: "object-select-symbolic"
                            color: networkItem.fg
                        }
                    }
                }

                Separator {
                    visible: NetworkService.hasWifi && NetworkService.hasEthernet
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }

                // ───────── Kabelgebunden ─────────
                MenuSectionLabel {
                    visible: NetworkService.hasEthernet
                    text: "Kabelgebunden"
                }

                // Kabelgebunden an/aus
                PopupMenuItem {
                    id: ethToggleItem
                    visible: NetworkService.hasEthernet
                    Layout.fillWidth: true
                    closeOnActivate: false
                    icon: NetworkService.ethernetConnected ? "network-wired-symbolic" : "network-wired-disconnected-symbolic"
                    text: NetworkService.ethernetConnected ? (NetworkService.ethernetName || "Kabelgebunden") : (NetworkService.ethernetEnabled ? "Kabel getrennt" : "Kabelgebunden (aus)")
                    onActivated: NetworkService.toggleEthernet()

                    Icon {
                        visible: NetworkService.ethernetConnected
                        name: "object-select-symbolic"
                        color: ethToggleItem.fg
                    }
                }

                Separator {
                    visible: NetworkService.vpnConnections.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }

                // ───────── VPN ─────────
                MenuSectionLabel {
                    visible: NetworkService.vpnConnections.length > 0
                    text: "VPN"
                }

                Repeater {
                    model: NetworkService.vpnConnections

                    PopupMenuItem {
                        id: vpnItem
                        required property var modelData
                        Layout.fillWidth: true
                        closeOnActivate: false
                        icon: "network-vpn-symbolic"
                        text: modelData.name
                        onActivated: NetworkService.toggleVpn(modelData)

                        Icon {
                            visible: vpnItem.modelData.active
                            name: "object-select-symbolic"
                            color: vpnItem.fg
                        }
                    }
                }
                Separator {
                    visible: SessionService.canOpenSettings
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }
                PopupMenuItem {
                    visible: SessionService.canOpenSettings
                    text: "Netzwerkeinstellungen"
                    closeOnActivate: false
                    onActivated: root.openSettingsPanel("network")
                }
            }

            // Bluetooth-Geräte [bluetooth.js:199-260, 330-425]
            QuickMenu {
                id: bluetoothMenu
                z: 2
                width: body.width
                y: stack.y + grid.y + grid.menuY(bluetoothTile)
                open: root.openMenu === "bluetooth"
                onCloseRequested: root.openMenu = ""
                headerIcon: "bluetooth-active-symbolic"
                headerTitle: "Bluetooth"
                headerActive: bluetoothTile.checked

                // Gekoppelte Geräte zuerst, darunter die während der Suche entdeckten [bluetooth.js:161-174]
                readonly property var deviceList: BluetoothService.enabled ? BluetoothService.pairedDevices.concat(BluetoothService.nearbyDevices) : []
                // Nach Geräten in der Nähe suchen, solange das Menü offen ist
                onOpenChanged: open ? BluetoothService.requestDiscovery("quicksettings.bluetooth") : BluetoothService.releaseDiscovery("quicksettings.bluetooth")

                headerSuffix: Spinner {
                    running: BluetoothService.discoveryRequested && BluetoothService.enabled
                    color: Theme.fgColor
                }

                Repeater {
                    model: bluetoothMenu.deviceList

                    PopupMenuItem {
                        id: deviceItem
                        required property var modelData
                        readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                        readonly property bool paired: modelData.paired || modelData.bonded
                        Layout.fillWidth: true
                        icon: (modelData.icon || "bluetooth") + "-symbolic"
                        text: modelData.name
                        onActivated: BluetoothService.toggleDevice(modelData)

                        Spinner {
                            running: deviceItem.busy
                            color: deviceItem.fg
                        }
                        Text {
                            visible: !deviceItem.busy
                            text: deviceItem.modelData.connected ? "Trennen" : (deviceItem.paired ? "Verbinden" : "Koppeln")
                            color: Theme.transparentize(deviceItem.fg, 0.5) // .device-subtitle [_quick-settings.scss:244]
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            font.weight: Theme.fontWeightNormal
                        }
                    }
                }
                // Platzhalter ohne Geräte (.bt-menu-placeholder, title-4, zentriert)
                Text {
                    visible: !BluetoothService.enabled || bluetoothMenu.deviceList.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.menuPlaceholderPaddingV
                    Layout.bottomMargin: Theme.menuPlaceholderPaddingV
                    Layout.leftMargin: Theme.menuPlaceholderPaddingH
                    Layout.rightMargin: Theme.menuPlaceholderPaddingH
                    text: BluetoothService.enabled ? "Keine Geräte in der Nähe" : "Bluetooth einschalten, um Geräte zu verbinden"
                    color: Theme.fgColor
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeTitle4
                    font.weight: Theme.fontWeightBold
                }
                Separator {
                    visible: SessionService.canOpenSettings
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }
                PopupMenuItem {
                    visible: SessionService.canOpenSettings
                    text: "Bluetooth-Einstellungen"
                    closeOnActivate: false
                    onActivated: root.openSettingsPanel("bluetooth")
                }
            }

            // Energiemodus [powerProfiles.js:60-100]
            QuickMenu {
                id: profileMenu
                z: 2
                width: body.width
                y: stack.y + grid.y + grid.menuY(profileTile)
                open: root.openMenu === "profile"
                onCloseRequested: root.openMenu = ""
                headerIcon: "power-profile-balanced-symbolic"
                headerTitle: "Energiemodus"
                headerActive: profileTile.checked

                Repeater {
                    // GNOME-Reihenfolge: Leistung, Ausbalanciert, Energiesparen
                    model: PowerService.profiles.slice().reverse()

                    PopupMenuItem {
                        required property string modelData
                        Layout.fillWidth: true
                        ornamented: true
                        ornamentChecked: modelData === PowerService.profile
                        icon: root.profileInfo[modelData].icon
                        text: root.profileInfo[modelData].name
                        onActivated: PowerService.setProfile(modelData)
                    }
                }
            }

            // Leistung: Menü mit den Energieprofilen (Leistung/Ausbalanciert/Energiesparen)
            QuickMenu {
                id: performanceMenu
                z: 2
                width: body.width
                y: stack.y + grid.y + grid.menuY(performanceTile)
                open: root.openMenu === "performance"
                onCloseRequested: root.openMenu = ""
                headerIcon: "power-profile-performance-symbolic"
                headerTitle: "Leistung"
                headerActive: performanceTile.checked

                Repeater {
                    // GNOME-Reihenfolge: Leistung, Ausbalanciert, Energiesparen
                    model: PowerService.profiles.slice().reverse()

                    PopupMenuItem {
                        required property string modelData
                        Layout.fillWidth: true
                        ornamented: true
                        ornamentChecked: modelData === PowerService.profile
                        icon: root.profileInfo[modelData].icon
                        text: root.profileInfo[modelData].name
                        onActivated: PowerService.setProfile(modelData)
                    }
                }
            }

            // Tastaturlayouts
            QuickMenu {
                id: keyboardMenu
                z: 2
                width: body.width
                y: stack.y + grid.y + grid.menuY(keyboardTile)
                open: root.openMenu === "keyboard"
                onCloseRequested: root.openMenu = ""
                headerIcon: "input-keyboard-symbolic"
                headerTitle: "Tastaturlayout"

                Repeater {
                    model: KeyboardService.layouts

                    PopupMenuItem {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        ornamented: true
                        ornamentChecked: index === KeyboardService.activeIndex
                        text: modelData
                        onActivated: KeyboardService.setLayout(index)
                    }
                }
            }

            // Hintergrundprogramme [backgroundApps.js:121-212]: Kopf mit Geist-Symbol, Hinweiszeile, laufende
            // Anwendungen (Icon, Name, Schließen-Knopf), Trenner und Einstieg in die Anwendungseinstellungen.
            QuickMenu {
                id: backgroundMenu
                z: 2
                width: body.width
                y: stack.y + backgroundSlot.y
                open: root.openMenu === "background"
                onCloseRequested: root.openMenu = ""
                headerIcon: Quickshell.shellPath("assets/icons/background-app-ghost-symbolic.svg")
                headerTitle: "Hintergrundprogramme"

                // .list-title: nicht reaktiv, umbrechender Hinweistext
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.menuItemPaddingH
                    Layout.rightMargin: Theme.menuItemPaddingH
                    Layout.topMargin: Theme.menuItemPaddingV
                    Layout.bottomMargin: Theme.menuItemPaddingV
                    text: "Programme, die im Hintergrund laufen"
                    color: Theme.fgColor
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightNormal
                }

                Repeater {
                    model: root.backgroundItems

                    BackgroundAppItem {
                        required property var modelData
                        item: modelData
                        popupRef: popup
                        onDismissed: root.hideBackground(modelData.id)
                    }
                }

                Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.basePadding
                    Layout.bottomMargin: Theme.basePadding
                }

                PopupMenuItem {
                    text: "Anwendungseinstellungen"
                    closeOnActivate: false
                    onActivated: root.openSettingsPanel("apps")
                }
            }
        }
    }
}
