import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.components

Item {
    id: root

    required property var screen
    required property var info
    required property real viewScale
    property bool showWindows: true
    property real cornerRadius: Theme.radiusThumbnail
    property bool sharedWallpaper: false
    property var captures: null

    signal activated
    signal windowDropped(var toplevel)
    signal appDropped(var entry)

    readonly property bool dropHover: drop.containsDrag
    readonly property real porthole: screen.height - Theme.panelHeight

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["niselle-window", "niselle-app"]
        onDropped: event => {
            if (event.source && event.source.toplevel) {
                event.accept(Qt.MoveAction);
                root.windowDropped(event.source.toplevel);
            } else if (event.source && event.source.entry && event.source.gridKind !== "folder") {
                event.accept(Qt.CopyAction);
                if (event.source.flyTo && event.source.parent)
                    event.source.flyTo(root.mapToItem(event.source.parent, root.width / 2, root.height / 2));
                root.appDropped(event.source.entry);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.thumbnailBackground
        border.width: Theme.thumbnailBorder
        border.color: "transparent"
    }

    Item {
        id: clipped
        anchors.fill: parent
        anchors.margins: Theme.thumbnailBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Item {
            id: monitorView
            y: -Theme.panelHeight * root.viewScale
            width: root.screen.width * root.viewScale
            height: root.screen.height * root.viewScale

            Image {
                anchors.fill: parent
                source: WallpaperService.sourceFor(root.screen.name)
                sourceSize.width: root.sharedWallpaper ? 0 : width
                sourceSize.height: root.sharedWallpaper ? 0 : height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: root.sharedWallpaper
            }

            Repeater {
                model: root.showWindows && root.info.workspace ? root.info.workspace.toplevels : null

                Rectangle {
                    id: win

                    required property var modelData

                    readonly property var at: modelData.lastIpcObject?.at ?? [0, 0]
                    readonly property var size: modelData.lastIpcObject?.size ?? [0, 0]
                    readonly property Item capture: root.captures ? root.captures.itemFor(modelData.address) : null

                    x: (at[0] - root.screen.x) * root.viewScale
                    y: (at[1] - root.screen.y) * root.viewScale
                    width: size[0] * root.viewScale
                    height: size[1] * root.viewScale
                    radius: Math.max(1, Math.min(3, width * 0.1, height * 0.1))
                    color: Theme.thumbnailBg

                    ShaderEffectSource {
                        id: mirror
                        anchors.fill: parent
                        sourceItem: win.capture
                        hideSource: false
                        live: false
                        textureSize: Qt.size(Math.max(1, Math.ceil(win.width * 2)), Math.max(1, Math.ceil(win.height * 2)))
                        visible: !!win.capture && win.capture.hasContent
                        onSourceItemChanged: scheduleUpdate()
                        onTextureSizeChanged: scheduleUpdate()
                        onVisibleChanged: if (visible) scheduleUpdate()
                    }
                    Connections {
                        target: OverviewService
                        function onRefreshCaptures(activeOnly) {
                            mirrorRefresh.restart();
                        }
                    }
                    Timer {
                        id: mirrorRefresh
                        interval: 120
                        onTriggered: mirror.scheduleUpdate()
                    }
                    Timer {
                        interval: 250
                        repeat: true
                        running: SettingsService.overviewLiveWindows && OverviewService.captureArmed && !OverviewService.animating
                        onTriggered: mirror.scheduleUpdate()
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.dropHover
            color: Theme.thumbnailDropOverlay
        }
    }

    Item {
        id: mask
        anchors.fill: clipped
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: Math.max(0, root.cornerRadius - Theme.thumbnailBorder)
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: root.info.empty && !root.info.workspace
        name: "list-add-symbolic"
        size: Theme.iconSize
        color: Theme.systemFg
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }
}
