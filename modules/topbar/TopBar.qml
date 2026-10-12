import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.datemenu
import qs.modules.quicksettings

// Top Bar (#panel) [_panel.scss, panel.js]: nur auf dem primären Monitor (siehe shell.qml), 32 px, volle Breite, reserviert ihren Platz.
// Schwarz, in der Übersicht transparent (Übergang 250 ms). Welche Elemente (Arbeitsflächen, fokussierte App, Uhr, Aufnahme,
// Tastaturlayout, Quick-Settings-Pille) in welcher Zone (links/Mitte/rechts) stehen, bestimmt SettingsService.barLayout. StatusNotifier-Einträge liegen jetzt in
// den Quick-Settings unter „Hintergrundprogramme“.
PanelWindow {
    id: root

    // Übersicht ist offen: Hintergrund transparent, Vordergrund wie Systemtext
    property bool overview: false
    // Übersicht ist sichtbar (auch beim Schließen): die Leiste liegt über ihr
    property bool overviewVisible: false
    // Zustand der zugehörigen Popups (aktiver Pillen-Zustand)
    readonly property bool calendarOpen: dateMenu.open
    readonly property bool quickSettingsOpen: quickSettings.open

    signal calendarRequested
    signal quickSettingsRequested
    signal overviewRequested

    readonly property color foreground: overview ? Theme.panelFgSystem : Theme.panelFg

    DateMenu {
        id: dateMenu
        barWindow: root
    }

    QuickSettings {
        id: quickSettings
        barWindow: root
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.panelHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.panelHeight
    color: "transparent"

    // Top, außer die Übersicht öffnet über einem Vollbildfenster: Hyprland zeichnet Vollbildfenster über der Top-Ebene,
    // die Leiste wäre dort unsichtbar. Dann liegt sie für die Dauer der Übersicht in der Overlay-Ebene.
    // Der Wert wird beim Öffnen festgehalten und erst nach dem Schließen zurückgesetzt: dann deckt das Vollbildfenster
    // die Leiste wieder ab, ein Ebenenwechsel mitten in der Übersicht (kurzes Aufblitzen) findet nicht statt.
    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool fullscreenActive: {
        void WorkspaceService.geometryRevision;
        const ws = hyprMonitor ? hyprMonitor.activeWorkspace : null;
        return !!ws && ws.toplevels.values.some(t => (t.lastIpcObject?.fullscreen ?? 0) > 0);
    }
    property bool overlayLatched: false
    // Beim Öffnen über ein Vollbildfenster in die Overlay-Ebene wechseln; auch dann noch, wenn der Vollbildzustand
    // erst nach dem Öffnen bekannt wird. Erst zurücksetzen, wenn die Übersicht vollständig geschlossen ist.
    function _syncOverlayLatch() {
        if (!overviewVisible)
            overlayLatched = false;
        else if (fullscreenActive)
            overlayLatched = true;
    }
    onOverviewVisibleChanged: _syncOverlayLatch()
    onFullscreenActiveChanged: _syncOverlayLatch()

    WlrLayershell.layer: overlayLatched ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "niselle-topbar"

    // Fortschritt der Übersicht treibt den Übergang Leistenfarbe ↔ Abdunklung
    readonly property real overviewProgress: Math.max(0, Math.min(1, OverviewService.progress))

    // Abdunklung wie in der Übersicht, solange diese offen ist
    Rectangle {
        anchors.fill: parent
        color: Theme.overviewBg
        // Deckend (Grundfläche): ein Überblenden zweier halbtransparenter Flächen ließ den Hintergrund durchscheinen (Aufblitzen)
        // Transparent: Grundfläche nur in der Übersicht deckend
        opacity: SettingsService.transparentBar ? root.overviewProgress * Theme.overviewScrimOpacity : Theme.overviewScrimOpacity
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        // Transparent: kein Panel-Hintergrund; in der Übersicht deckt die Grundfläche in der Farbe der Übersicht
        opacity: SettingsService.transparentBar ? 0 : 1 - root.overviewProgress

        // Nur hell: Haarlinie am unteren Rand [_panel:20-23]
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 0.5
            color: Theme.panelBorder
        }
    }

    // Eine Zone der Leiste: die Elemente stehen in der Reihenfolge aus den Einstellungen (SettingsService.barLayout).
    // Ausgeblendete Elemente (z. B. fehlender App-Name) nehmen keine Breite ein.
    component Zone: RowLayout {
        id: zone

        property var ids: []

        spacing: 0

        Repeater {
            model: zone.ids

            Loader {
                id: slot

                required property string modelData

                Layout.fillHeight: true
                Layout.preferredWidth: item && item.visible ? item.implicitWidth : 0
                sourceComponent: root.itemComponents[modelData] ?? null

                // Bildschirmposition des Elements für die Panels veröffentlichen (Theme.setBarAnchor);
                // siehe components/BarAnchor.qml und die Panels in DateMenu/QuickSettings
                function publishAnchor() {
                    const it = item;
                    if (!it || !it.visible || it.width <= 0 || it.height <= 0)
                        return;
                    const p = it.mapToItem(null, 0, 0);
                    Theme.setBarAnchor(modelData, p.x, p.y, it.width, it.height);
                }
                onItemChanged: publishAnchor()
                Connections {
                    target: slot.item

                    function onXChanged() {
                        slot.publishAnchor();
                    }
                    function onYChanged() {
                        slot.publishAnchor();
                    }
                    function onWidthChanged() {
                        slot.publishAnchor();
                    }
                    function onHeightChanged() {
                        slot.publishAnchor();
                    }
                    function onVisibleChanged() {
                        slot.publishAnchor();
                    }
                }
            }
        }
    }

    readonly property var itemComponents: ({
            "workspaces": workspacesItem,
            "activeWindow": activeWindowItem,
            "clock": clockItem,
            "keyboard": keyboardItem,
            "status": statusItem
        })

    Component {
        id: workspacesItem
        WorkspaceIndicator {
            screen: root.screen
            foreground: root.foreground
            checked: root.overview
            onOverviewRequested: root.overviewRequested()
        }
    }
    Component {
        id: activeWindowItem
        AppIndicator {
            foreground: root.foreground
            visible: !root.overview && appName !== ""
        }
    }
    Component {
        id: clockItem
        ClockButton {
            foreground: root.foreground
            checked: root.calendarOpen
            onCalendarRequested: {
                dateMenu.toggle();
                root.calendarRequested();
            }
        }
    }
    Component {
        id: keyboardItem
        KeyboardIndicator {
            foreground: root.foreground
        }
    }
    // Systemmenü: Aufnahme-/Freigabe-Pillen (nur sichtbar, solange etwas läuft) direkt links neben der Statuspille
    Component {
        id: statusItem
        RowLayout {
            spacing: 0

            CaptureIndicators {
                Layout.fillHeight: true
                foreground: root.foreground
            }
            QuickSettingsButton {
                Layout.fillHeight: true
                foreground: root.foreground
                checked: root.quickSettingsOpen
                onQuickSettingsRequested: {
                    quickSettings.toggle();
                    root.quickSettingsRequested();
                }
            }
        }
    }

    Zone {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        ids: SettingsService.barLayout.left
    }
    Zone {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        ids: SettingsService.barLayout.center
    }
    Zone {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        ids: SettingsService.barLayout.right
    }
}
