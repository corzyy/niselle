import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

Item {
    id: root

    required property var screen
    required property real workHeight

    required property var wsModel
    required property var captures

    readonly property int count: wsModel.count
    readonly property bool shouldShow: count > 2 || OverviewService.windowDragActive

    readonly property real portholeWidth: screen.width
    readonly property real portholeHeight: screen.height - Theme.panelHeight

    readonly property real totalSpacing: (count - 1) * Theme.thumbnailsSpacing
    readonly property real contentWidth: width - 2 * Theme.thumbnailsPadding
    readonly property real prefScale: Math.min(((contentWidth - totalSpacing) / Math.max(1, count)) / portholeWidth, Theme.thumbnailsMaxScale)
    readonly property real naturalHeight: Math.round(portholeHeight * prefScale) + 2 * Theme.thumbnailsPadding
    readonly property real fullHeight: Math.min(naturalHeight, workHeight * Theme.thumbnailsMaxScale)

    property real expand: shouldShow ? 1 : 0
    Behavior on expand {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Theme.easeOut
        }
    }

    visible: expand > 0
    implicitHeight: Math.round(fullHeight * expand)
    Behavior on implicitHeight {
        enabled: OverviewService.shown && (!OverviewService.animating) && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    readonly property real availW: (contentWidth - totalSpacing) / Math.max(1, count)
    readonly property real availH: fullHeight - 2 * Theme.thumbnailsPadding
    readonly property real thumbScale: Math.min(availW / portholeWidth, availH / portholeHeight)

    property real shownScale: thumbScale
    property real shownCount: count
    Behavior on shownScale {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }
    Behavior on shownCount {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    readonly property real thumbFullHeight: Math.round(portholeHeight * shownScale)
    readonly property real thumbWidth: Math.round(thumbFullHeight * (portholeWidth / portholeHeight))
    readonly property real pitch: thumbWidth + Theme.thumbnailsSpacing
    readonly property real rowWidth: shownCount * pitch - Theme.thumbnailsSpacing
    readonly property real rowX: Math.round((width - rowWidth) / 2)

    readonly property real activeThumbX: rowX + wsModel.position * pitch
    readonly property rect activeRect: {
        void OverviewService.progress;
        const p = root.mapToItem(null, root.activeThumbX, Theme.thumbnailsPadding);
        return Qt.rect(p.x, p.y, root.thumbWidth, root.thumbFullHeight);
    }
    Binding {
        target: OverviewService
        property: "activeThumbnailRect"
        value: root.activeRect
        when: OverviewService.appsShown || OverviewService.appsProgress > 0
        restoreMode: Binding.RestoreNone
    }

    Item {
        id: strip
        x: 0
        y: Theme.thumbnailsPadding
        width: parent.width
        height: root.thumbFullHeight
        opacity: root.expand

        Repeater {
            model: wsModel.model

            WorkspaceThumbnail {
                id: thumb

                required property int wsId
                required property bool gone

                readonly property var entry: wsModel.infoFor(wsId)

                readonly property real targetSlot: wsModel.slotFor(wsId)
                property real slot: targetSlot
                Behavior on slot {
                    enabled: OverviewService.shown && !Theme.gameMode
                    NumberAnimation {
                        duration: Theme.motionSlow
                        easing.type: Theme.easeOut
                    }
                }

                property real appear: 0
                Behavior on appear {
                    enabled: OverviewService.shown && !Theme.gameMode
                    NumberAnimation {
                        duration: Theme.motionFast
                        easing.type: Theme.easeOut
                    }
                }
                readonly property real wanted: gone ? 0 : 1
                onWantedChanged: appear = wanted
                Component.onCompleted: appear = wanted

                screen: root.screen
                info: entry
                captures: root.captures
                viewScale: root.shownScale
                sharedWallpaper: true
                x: root.rowX + Math.round(slot * root.pitch)
                width: root.thumbWidth
                height: root.thumbFullHeight
                opacity: appear
                scale: 1
                visible: appear > 0.01
                enabled: !gone

                onActivated: {
                    if (info.active)
                        OverviewService.hide();
                    else
                        WorkspaceService.switchTo(info.id, root.screen);
                }
                onAppDropped: entry => {
                    if (!info.workspace)
                        WorkspaceService.focusMonitor(root.screen);
                    WorkspaceService.launchOn(entry, info.id);
                }
                onWindowDropped: toplevel => {
                    if (toplevel.workspace && toplevel.workspace.id === info.id)
                        return;
                    if (!info.workspace)
                        WorkspaceService.focusMonitor(root.screen);
                    WorkspaceService.moveWindow(toplevel, info.id, false);
                }
            }
        }

        Rectangle {
            x: root.rowX + Math.round(wsModel.position * root.pitch) - Theme.thumbnailIndicatorBorder
            y: -Theme.thumbnailIndicatorBorder
            width: root.thumbWidth + 2 * Theme.thumbnailIndicatorBorder
            height: root.thumbFullHeight + 2 * Theme.thumbnailIndicatorBorder
            radius: Theme.radiusThumbnailIndicator
            color: "transparent"
            border.width: Theme.thumbnailIndicatorBorder
            border.color: Theme.accentColor
        }
    }
}
