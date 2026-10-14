import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import qs.modules.dash

PanelWindow {
    id: root

    readonly property real progress: OverviewService.progress
    readonly property bool primary: OverviewService.isPrimary(screen)

    readonly property real screenWidth: root.screen ? root.screen.width : root.width
    readonly property real screenHeight: root.screen ? root.screen.height : root.height

    WorkspaceModel {
        id: screenWorkspaces
        screen: root.screen
    }
    CaptureRegistry {
        id: captureRegistry
    }

    property bool appGridWarm: false

    readonly property alias searchSlot: searchSlot
    readonly property alias thumbnailsSlot: thumbnailsSlot
    readonly property alias windowsSlot: windowsSlot
    readonly property alias dashSlot: dashSlot
    readonly property alias dragOverlayItem: dragOverlay

    readonly property real workTop: primary ? Theme.panelHeight : 0
    readonly property real workHeight: screenHeight - workTop
    readonly property real spacing: Math.round(workHeight * Theme.overviewSpacingRatio)

    readonly property real searchHeight: primary ? searchSlot.implicitHeight : 0
    readonly property real dashHeight: primary ? Math.min(dashSlot.implicitHeight, Math.round(workHeight * Theme.overviewDashMaxHeightRatio)) : 0
    readonly property real thumbnailsHeight: primary ? thumbnailsSlot.implicitHeight : 0
    readonly property real workBottom: workTop + workHeight - dashHeight - spacing

    readonly property real thumbnailsY: workTop + searchHeight + Math.round(spacing * Theme.overviewThumbnailsSpacingTop)
    readonly property real thumbnailsGap: thumbnailsHeight > 0 ? Math.round(spacing * Theme.overviewThumbnailsSpacingBottom) : 0

    readonly property rect hiddenBox: Qt.rect(0, workTop, screenWidth, workHeight)
    readonly property rect pickerBox: {
        if (!primary) {
            const padX = Math.round((1 - Theme.overviewSecondaryScale) * screenWidth / 2);
            const padY = Math.round((1 - Theme.overviewSecondaryScale) * workHeight / 2);
            return Qt.rect(padX, workTop + padY, screenWidth - 2 * padX, workHeight - 2 * padY);
        }
        const y = thumbnailsY + thumbnailsHeight + thumbnailsGap;
        return Qt.rect(0, y, screenWidth, workTop + workHeight - dashHeight - spacing - y);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool fullscreenActive: {
        void WorkspaceService.geometryRevision;
        void WorkspaceService.revision;
        return !!monitor?.activeWorkspace?.lastIpcObject?.hasfullscreen;
    }
    readonly property bool open: OverviewService.visible
    visible: open || (!Theme.gameMode && !(OverviewService.scanoutSensitive && fullscreenActive))
    mask: Region {
        x: root.open ? 0 : root.screenWidth - 1
        y: root.open ? root.workTop : root.screenHeight - 1
        width: root.open ? root.screenWidth : 1
        height: root.open ? root.workHeight : 1
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-overview"
    WlrLayershell.keyboardFocus: primary && OverviewService.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        anchors.topMargin: root.workTop
        clip: true
        visible: Theme.blur && !Theme.gameMode
        opacity: Math.min(1, root.progress * 2)

        Image {
            y: -root.workTop
            width: root.width
            height: root.height
            source: WallpaperService.awwwSourceFor(root.screen.name)
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: 1
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.workTop
        color: Theme.overviewBg
        opacity: (Theme.blur && !Theme.gameMode ? 0.35 : Theme.overviewScrimOpacity) * root.progress

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (!OverviewService.animating)
                    OverviewService.hide();
            }
        }
    }

    Image {
        visible: false
        width: 1
        height: 1
        source: WallpaperService.awwwSourceFor(root.screen.name)
        cache: true
    }

    FocusScope {
        id: keys

        property bool superArmed: false

        anchors.fill: parent
        opacity: root.open ? 1 : 0
        focus: OverviewService.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                OverviewService.dismiss();
                event.accepted = true;
            } else if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                if (!event.isAutoRepeat)
                    keys.superArmed = true;
                event.accepted = true;
            } else {
                keys.superArmed = false;
            }
        }
        Keys.onReleased: event => {
            if (event.key !== Qt.Key_Super_L && event.key !== Qt.Key_Super_R)
                return;
            if (keys.superArmed)
                OverviewService.hide();
            keys.superArmed = false;
            event.accepted = true;
        }

        OverviewSlot {
            id: windowsSlot
            x: root.hiddenBox.x + (root.pickerBox.x - root.hiddenBox.x) * root.progress
            y: root.hiddenBox.y + (root.pickerBox.y - root.hiddenBox.y) * root.progress
            width: root.hiddenBox.width + (root.pickerBox.width - root.hiddenBox.width) * root.progress
            height: root.hiddenBox.height + (root.pickerBox.height - root.hiddenBox.height) * root.progress
            z: OverviewService.appsProgress > 0 ? 5 : 0
            opacity: root.primary ? 1 - Math.max(0, Math.min(1, (OverviewService.appsProgress - 0.6) / 0.4)) : 1
            enabled: OverviewService.appsProgress < 0.5 && OverviewService.searchProgress < 0.5

            Item {
                x: -windowsSlot.x
                y: root.workTop - windowsSlot.y
                width: root.screenWidth
                height: root.screenHeight - root.workTop
                clip: true

                Loader {
                    y: -root.workTop
                    width: root.screenWidth
                    height: root.screenHeight
                    active: true

                    sourceComponent: WindowPicker {
                        screen: root.screen
                        hiddenBox: root.hiddenBox
                        pickerBox: root.pickerBox
                        progress: root.progress
                        appsProgress: OverviewService.appsProgress
                        primary: root.primary
                        dragLayer: dragOverlay
                        windowWidth: root.screenWidth
                        windowHeight: root.screenHeight
                        wsModel: screenWorkspaces
                        captures: captureRegistry
                    }
                }
            }
        }

        OverviewSlot {
            id: appsSlot
            readonly property real p: OverviewService.appsProgress > 0 || OverviewService.appsShown ? root.progress : 1
            x: root.hiddenBox.x + (root.pickerBox.x - root.hiddenBox.x) * p
            y: root.hiddenBox.y + (root.pickerBox.y - root.hiddenBox.y) * p
            width: root.hiddenBox.width + (root.pickerBox.width - root.hiddenBox.width) * p
            height: root.hiddenBox.height + (root.pickerBox.height - root.hiddenBox.height) * p
            opacity: Math.min(1, OverviewService.appsProgress * 2.5)
            visible: root.primary && OverviewService.appsProgress > 0
            enabled: root.primary && OverviewService.appsProgress > 0.5 && OverviewService.searchProgress < 0.5

            Loader {
                width: root.pickerBox.width
                height: root.pickerBox.height
                anchors.centerIn: parent
                scale: Math.min(parent.width / Math.max(1, width), parent.height / Math.max(1, height))
                active: root.primary && (OverviewService.appsShown || OverviewService.appsProgress > 0 || root.appGridWarm)

                sourceComponent: AppGrid {
                    screen: root.screen
                    dragOverlay: root.dragOverlayItem
                }
            }
        }

        Item {
            id: topClip
            y: root.workTop
            width: root.screenWidth
            height: root.screenHeight - root.workTop
            clip: true

        OverviewSlot {
            id: searchSlot
            visible: root.primary
            x: 0
            y: -(1 - root.progress) * (root.workTop + height)
            width: parent.width
            opacity: root.progress

            SearchBar {
                id: searchBar
                anchors.left: parent.left
                anchors.right: parent.right
                onAccepted: searchResults.activateSelected()
                onMoveSelection: (dx, dy) => searchResults.moveSelection(dx, dy)
                onEscapePressed: OverviewService.dismiss()
            }
        }

        OverviewSlot {
            id: thumbnailsSlot
            visible: root.primary
            x: 0
            y: root.thumbnailsY - root.workTop - (1 - root.progress) * (root.thumbnailsY + height)
            width: parent.width
            opacity: root.progress
            enabled: OverviewService.searchProgress < 0.5

            Loader {
                anchors.fill: parent
                active: root.primary

                sourceComponent: WorkspaceThumbnails {
                    screen: root.screen
                    workHeight: root.workHeight
                    wsModel: screenWorkspaces
                    captures: captureRegistry
                }
            }
        }

        }

        OverviewSlot {
            id: dashSlot
            visible: root.primary
            x: 0
            y: root.screenHeight - root.dashHeight + (1 - root.progress) * root.dashHeight
            width: root.screenWidth
            height: root.dashHeight
            opacity: root.progress

            Loader {
                anchors.fill: parent
                active: root.primary

                sourceComponent: Dash {
                    dragOverlay: root.dragOverlayItem
                    maxWidth: root.screenWidth
                    maxHeight: Math.round(root.workHeight * Theme.overviewDashMaxHeightRatio)
                }
            }
        }

        Item {
            id: searchOverlay
            visible: root.primary && (OverviewService.searchProgress > 0 || panelSpringProgress > 0)
            anchors.fill: parent
            z: 20

            property real panelSpringProgress: OverviewService.searchActive ? 1 : 0
            Behavior on panelSpringProgress {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: OverviewService.searchActive ? Theme.motionMedium : Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: root.workTop
                color: "black"
                opacity: Theme.searchOverlayScrim * OverviewService.searchProgress

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: SearchService.reset()
                }
            }

            OverlayLayer {
                screen: root.screen
                layerNamespace: "niselle-search"
                visible: searchOverlay.visible
                maskRect: Qt.rect(searchPanel.x - 16, searchPanel.y - 16, searchPanel.width + 32, searchPanel.height + 32)

                ShadowRect {
                    id: searchPanel

                    readonly property real maxHeight: Math.max(0, root.workBottom - y)

                    x: Math.round((root.screenWidth - width) / 2)
                    y: root.workTop + root.searchHeight + (1 - searchOverlay.panelSpringProgress) * Theme.searchOverlayStartOffset
                    width: Math.min(Theme.searchOverlayWidth, root.screenWidth - 2 * Theme.searchOverlayPadding)
                    height: Math.min(maxHeight, searchResults.total > 0 ? searchResults.wantedHeight : Theme.searchOverlayMinHeight)
                    color: Theme.glass(Theme.systemOverlayBg)
                    radius: Theme.searchOverlayRadius
                    opacity: searchOverlay.panelSpringProgress

                    Behavior on height {
                        enabled: !Theme.gameMode && OverviewService.searchProgress >= 1
                        NumberAnimation {
                            duration: Theme.durationButton
                            easing.type: Theme.easeEmphasized
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                    }

                    SearchResults {
                        id: searchResults
                        anchors.fill: parent
                        anchors.margins: Theme.searchOverlayPadding
                    }
                }
            }
        }

        OverlayLayer {
            screen: root.screen
            layerNamespace: "niselle-folder"
            visible: folderDialog.primary && (folderDialog.fade > 0 || folderDialog.open)
            keyboardFocus: folderDialog.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            AppFolderDialog {
                id: folderDialog
                windowWidth: root.screenWidth
                windowHeight: root.screenHeight
                primary: root.primary
                z: 200
            }
        }

        Item {
            id: dragOverlay
            anchors.fill: parent
            z: 100
        }

        Rectangle {
            readonly property bool foreign: OverviewService.windowDragActive && OverviewService.windowDragScreen !== root.screen.name
            parent: dragOverlay
            visible: foreign
            width: OverviewService.windowDragSize.width
            height: OverviewService.windowDragSize.height
            x: OverviewService.windowDragPoint.x - root.screen.x - width / 2
            y: OverviewService.windowDragPoint.y - root.screen.y - height / 2
            radius: Theme.radiusThumbnail
            color: Theme.thumbnailBg
            opacity: Theme.windowDraggingOpacity * 2.5

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 6

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: OverviewService.windowDragActive && OverviewService.windowDragIcon !== ""
                    sourceComponent: Icon {
                        name: OverviewService.windowDragIcon
                        symbolic: false
                        size: Math.min(OverviewService.windowDragSize.width, OverviewService.windowDragSize.height) * 0.4
                    }
                }
                Text {
                    width: parent.width - 16
                    x: 8
                    text: OverviewService.windowDragTitle
                    color: Theme.systemFg
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
            }
        }

        WheelHandler {
            property real accumulated: 0
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (!OverviewService.shown || OverviewService.searchActive) {
                    accumulated = 0;
                    return;
                }
                accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                const step = Theme.overviewWheelStep;
                if (Math.abs(accumulated) < step)
                    return;
                WorkspaceService.switchRelative(accumulated < 0 ? 1 : -1, root.screen);
                accumulated = 0;
            }
        }

        Connections {
            target: OverviewService
            function onShownChanged() {
                if (OverviewService.shown && root.primary)
                    searchBar.forceFocus();
            }
            function onAppsShownChanged() {
                if (OverviewService.appsShown)
                    root.appGridWarm = true;
            }
        }
    }
}
