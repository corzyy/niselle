import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.datemenu
import qs.modules.quicksettings

PanelWindow {
    id: root

    property bool overview: false
    property bool overviewVisible: false
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

    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool fullscreenActive: {
        void WorkspaceService.geometryRevision;
        const ws = hyprMonitor ? hyprMonitor.activeWorkspace : null;
        return !!ws && ws.toplevels.values.some(t => (t.lastIpcObject?.fullscreen ?? 0) > 0);
    }
    property bool overlayLatched: false
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

    readonly property real overviewProgress: Math.max(0, Math.min(1, OverviewService.progress))

    Rectangle {
        anchors.fill: parent
        color: Theme.overviewBg
        opacity: SettingsService.transparentBar ? root.overviewProgress * Theme.overviewScrimOpacity : Theme.overviewScrimOpacity
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        opacity: SettingsService.transparentBar ? 0 : 1 - root.overviewProgress

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 0.5
            color: Theme.panelBorder
        }
    }

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
