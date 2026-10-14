import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import qs
import qs.services

Item {
    id: root

    required property var screen
    required property rect hiddenBox
    required property rect pickerBox
    required property real progress
    required property Item dragLayer
    required property real windowWidth
    required property real windowHeight
    required property real appsProgress
    required property bool primary
    required property var wsModel
    required property var captures

    readonly property rect flyTarget: OverviewService.activeThumbnailRect
    readonly property real fly: primary ? appsProgress : 0

    readonly property real sideInset: Theme.workspaceSideInset * progress
    readonly property real workspaceAspect: screen && screen.height > 0 ? screen.width / screen.height : 16 / 9

    readonly property rect workspaceBox: {
        const x = pickerBox.x * progress + sideInset;
        const y = pickerBox.y * progress;
        const availW = windowWidth + (pickerBox.width - windowWidth) * progress - 2 * sideInset;
        const availH = windowHeight + (pickerBox.height - windowHeight) * progress;
        let w = availW;
        let h = w / workspaceAspect;
        if (h > availH) {
            h = availH;
            w = h * workspaceAspect;
        }
        return Qt.rect(x + (availW - w) / 2, y + (availH - h) / 2, w, h);
    }

    readonly property real neighborGap: Math.max(Theme.workspaceSideInset, Math.round(workspaceBox.width * 0.04))
    readonly property real slideStep: workspaceBox.width + neighborGap
    Component.onCompleted: Hyprland.refreshToplevels()

    implicitHeight: 0

    Text {
        id: probe
        visible: false
        text: "Ag"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }
    readonly property real captionHeight: probe.implicitHeight + 2 * (Theme.tooltipPaddingV + Theme.tooltipBorderWidth)

    readonly property real topOversize: Theme.windowCloseSize / 2 + Theme.windowActiveSizeInc
    readonly property real bottomOversize: (1 - Theme.windowIconOverlap) * Theme.windowIconSize + Theme.windowActiveSizeInc
    readonly property real sideOversize: Theme.windowCloseSize / 2 + Theme.windowActiveSizeInc
    readonly property real oversize: Math.max(topOversize, bottomOversize, sideOversize)

    readonly property rect finalWorkspaceBox: {
        const inset = Theme.workspaceSideInset;
        const availW = pickerBox.width - 2 * inset;
        const availH = pickerBox.height;
        let w = availW;
        let h = w / workspaceAspect;
        if (h > availH) {
            h = availH;
            w = h * workspaceAspect;
        }
        return Qt.rect(pickerBox.x + inset + (availW - w) / 2, pickerBox.y + (availH - h) / 2, w, h);
    }
    readonly property rect finalWindowBox: {
        const pad = Math.round(finalWorkspaceBox.height * Theme.windowPickerPaddingRatio);
        return Qt.rect(finalWorkspaceBox.x + pad, finalWorkspaceBox.y + pad, Math.max(0, finalWorkspaceBox.width - 2 * pad), Math.max(0, finalWorkspaceBox.height - 2 * pad));
    }

    readonly property string wallpaperSource: WallpaperService.sourceFor(screen ? screen.name : "")
    readonly property Item wallpaperTexture: wallpaperSource !== "" ? wallpaperRounded : null

    Item {
        id: wallpaperPlain
        visible: false
        width: Math.max(1, Math.round(root.finalWorkspaceBox.width))
        height: Math.max(1, Math.round(root.finalWorkspaceBox.height))
        layer.enabled: true

        Image {
            anchors.fill: parent
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }
    Item {
        id: wallpaperMask
        visible: false
        width: wallpaperPlain.width
        height: wallpaperPlain.height
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.workspaceCornerRadius
        }
    }
    MultiEffect {
        id: wallpaperRounded
        visible: false
        width: wallpaperPlain.width
        height: wallpaperPlain.height
        source: wallpaperPlain
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: wallpaperMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        layer.enabled: true
        layer.smooth: true
    }

    Repeater {
        model: root.wsModel.model

        WorkspacePage {
            picker: root
            keyed: root.wsModel
        }
    }
}
