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

    required property var toplevel
    required property Item dragLayer
    property real progress: 1
    property real captureWidth: 0
    property real captureHeight: 0
    property var captures: null
    property bool streaming: false
    property bool activeWorkspace: false
    property bool captureEnabled: true

    signal selected

    readonly property alias container: container
    readonly property bool overlayShown: shown
    readonly property bool dragging: ghost.Drag.active

    property bool shown: false

    readonly property var entry: AppsService.entryForWindow(toplevel)
    readonly property string windowClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property string title: toplevel?.title || entry?.name || windowClass
    readonly property string iconSource: Quickshell.iconPath(entry?.icon || windowClass.toLowerCase(), "application-x-executable")

    function _iconPx() {
        return Math.max(16, Math.min(Math.min(width, height) * 0.42, Theme.windowIconSize * 1.8));
    }
    readonly property real iconPxFinal: captureWidth > 0 && captureHeight > 0 ? Math.max(16, Math.min(Math.min(captureWidth, captureHeight) * 0.42, Theme.windowIconSize * 1.8)) : Theme.windowIconSize

    readonly property real activeScale: {
        if (!shown)
            return 1;
        const orig = Math.max(width, height);
        return orig > 0 ? (orig + 2 * Theme.windowActiveSizeInc) / orig : 1;
    }

    z: shown ? 1 : 0


    Item {
        id: container
        anchors.fill: parent
        opacity: root.dragging ? 0 : 1
        scale: root.shown ? root.activeScale : 1
        transformOrigin: Item.Center

        Behavior on scale {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeOut
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Math.min(Theme.radiusThumbnail, root.width * 0.06, root.height * 0.06))
            color: Theme.thumbnailBg
            border.width: Theme.thumbnailBorder
            border.color: "transparent"
        }

        ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: root.captureEnabled ? (root.toplevel?.wayland ?? null) : null
            live: SettingsService.overviewLiveWindows && OverviewService.captureArmed && root.streaming
            paintCursor: false
            constraintSize: Qt.size(Math.max(1, root.captureWidth), Math.max(1, root.captureHeight))
            opacity: shot.hasContent ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }
        }

        function restartShot() {
            if (!root.toplevel?.wayland)
                return;
            root.captureEnabled = false;
            restartCapture.restart();
        }
        Connections {
            target: shot
            function onStopped() {
                shot.restartShot();
            }
        }
        Connections {
            target: Qt.application
            function onAboutToQuit() {
                restartCapture.stop();
                root.captureEnabled = false;
            }
        }
        Timer {
            id: restartCapture
            interval: 30
            onTriggered: root.captureEnabled = true
        }

        Connections {
            target: OverviewService
            function onRefreshCaptures(activeOnly) {
                if ((activeOnly && !root.activeWorkspace) || shot.live || restartCapture.running)
                    return;
                if (!shot.hasContent)
                    shot.restartShot();
                else
                    shot.captureFrame();
            }
            function onVisibleChanged() {
                if (!OverviewService.visible)
                    shot.restartShot();
            }
        }

        Column {
            id: tileContent
            anchors.centerIn: parent
            width: parent.width
            spacing: Math.round(root.height * 0.05)
            visible: root.width > 24 && root.height > 24 && opacity > 0

            property bool logoHidden: false
            opacity: logoHidden ? 0 : 1
            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }

            Timer {
                id: logoHold
                interval: Theme.motionSnap / 2
                onTriggered: tileContent.logoHidden = true
            }
            Connections {
                target: shot
                function onHasContentChanged() {
                    if (shot.hasContent) {
                        logoHold.start();
                    } else {
                        logoHold.stop();
                        tileContent.logoHidden = false;
                    }
                }
            }

            Item {
                width: parent.width
                height: glyph.implicitHeight * glyph.scale

                Icon {
                    id: glyph
                    anchors.centerIn: parent
                    name: root.iconSource
                    symbolic: false
                    size: root.iconPxFinal
                    scale: tileContent.visible ? root._iconPx() / root.iconPxFinal : 1
                }
            }

            Text {
                width: parent.width - Math.round(root.width * 0.16)
                x: Math.round(root.width * 0.08)
                visible: root.height >= 48 && root.width >= 64
                text: root.title
                color: Theme.systemFg
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
            }
        }
    }

    Component.onCompleted: root.captures?.register(root.toplevel?.address, shot)
    Component.onDestruction: root.captures?.unregister(root.toplevel?.address, shot)

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        property point pressPos
        property bool pressedLeft: false

        onPressed: mouse => {
            pressPos = Qt.point(mouse.x, mouse.y);
            pressedLeft = mouse.button === Qt.LeftButton;
        }
        onPositionChanged: mouse => {
            if (!pressedLeft || !pressed)
                return;
            if (!ghost.Drag.active) {
                if (Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) < Qt.styleHints.startDragDistance)
                    return;
                root.startDrag();
            }
            root.moveDrag(area.mapToItem(root.dragLayer, mouse.x, mouse.y));
        }
        onReleased: mouse => {
            if (ghost.Drag.active)
                root.endDrag();
        }
        onClicked: mouse => {
            if (ghost.Drag.active || (mouse.button === Qt.LeftButton && Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) >= Qt.styleHints.startDragDistance))
                return;
            if (mouse.button === Qt.MiddleButton)
                WorkspaceService.closeWindow(root.toplevel);
            else
                root.selected();
        }
    }


    readonly property bool hovered: area.containsMouse || closeHover.hovered
    onHoveredChanged: {
        if (hovered) {
            hideTimer.stop();
            shown = !dragging;
        } else {
            hideTimer.restart();
        }
    }
    onDraggingChanged: if (dragging) shown = false

    Timer {
        id: hideTimer
        interval: Theme.windowOverlayHideTimeout
        onTriggered: if (!root.hovered)
            root.shown = false
    }

    readonly property real heightIncrease: container.scale === 1 ? 0 : Math.floor(height * (container.scale - 1) / 2)
    readonly property real widthIncrease: container.scale === 1 ? 0 : Math.floor(width * (container.scale - 1) / 2)

    Rectangle {
        id: close
        visible: opacity > 0
        opacity: root.shown ? 1 : 0
        width: Theme.windowCloseSize
        height: Theme.windowCloseSize
        x: visible ? root.width - width / 2 + root.widthIncrease : 0
        y: visible ? -height / 2 - root.heightIncrease : 0
        radius: Theme.radiusPill
        color: closeMouse.pressed ? Theme.windowCloseBgActive : (closeMouse.containsMouse ? Theme.windowCloseBgHover : Theme.windowCloseBg)
        border.width: Theme.windowCloseBorder
        border.color: "transparent"

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeOut
            }
        }
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.motionSnap
                easing.type: Theme.easeOut
            }
        }

        Icon {
            anchors.centerIn: parent
            name: Quickshell.shellPath("assets/icons/preview-close-symbolic.svg")
            size: Theme.windowCloseIconSize
            color: Theme.systemFg
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: WorkspaceService.closeWindow(root.toplevel)
        }
        HoverHandler {
            id: closeHover
        }
    }


    Item {
        id: ghost
        parent: root.dragLayer
        visible: Drag.active
        readonly property real fit: Math.min(1, Theme.windowDndSize / Math.max(1, Math.max(root.width, root.height)))
        width: root.width * fit
        height: root.height * fit
        opacity: Theme.windowDraggingOpacity
        property var toplevel: root.toplevel

        Drag.active: false
        Drag.source: ghost
        Drag.keys: ["niselle-window"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.container
            live: false
            hideSource: false
            smooth: true
            Component.onCompleted: scheduleUpdate()
            visible: ghost.Drag.active
            onVisibleChanged: if (visible)
                scheduleUpdate()
        }

        scale: Drag.active ? 1 : 0.9
        Behavior on scale {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeOut
            }
        }
    }

    function startDrag() {
        ghost.Drag.active = true;
        const own = root.Window.window?.screen;
        OverviewService.windowDragScreen = own ? own.name : "";
        OverviewService.windowDragSize = Qt.size(ghost.width, ghost.height);
        OverviewService.windowDragIcon = root.iconSource;
        OverviewService.windowDragTitle = root.title;
        OverviewService.windowDragActive = true;
    }
    function moveDrag(p) {
        lastDragPoint = p;
        const own = root.Window.window?.screen;
        if (own)
            OverviewService.windowDragPoint = Qt.point(own.x + p.x, own.y + p.y);
        ghost.x = p.x - ghost.width / 2;
        ghost.y = p.y - ghost.height / 2;
    }
    function endDrag() {
        const action = ghost.Drag.drop();
        ghost.Drag.active = false;
        OverviewService.windowDragActive = false;
        if (action === Qt.IgnoreAction)
            root.dropOnOtherMonitor();
    }

    property point lastDragPoint: Qt.point(0, 0)
    function dropOnOtherMonitor() {
        const own = root.Window.window?.screen;
        if (!own || !toplevel)
            return;
        const gx = own.x + lastDragPoint.x;
        const gy = own.y + lastDragPoint.y;
        const target = Quickshell.screens.find(s => s !== own && gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height);
        if (!target)
            return;
        const ws = Hyprland.monitorFor(target)?.activeWorkspace;
        if (ws)
            WorkspaceService.moveWindow(toplevel, ws.id, false);
    }
}
