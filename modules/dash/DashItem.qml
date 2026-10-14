import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

Item {
    id: root

    required property var dash
    required property string kind
    required property string appId

    readonly property var entry: kind === "app" ? AppsService.byId(appId) : null
    readonly property var running: kind === "app" ? AppsService.runningFor(entry) : (AppsService.runningApps.find(r => r.appId.toLowerCase() === appId) ?? null)
    readonly property var windows: running ? running.windows : []
    readonly property bool favorite: entry ? AppsService.isFavorite(entry) : false
    readonly property string label: entry?.name ?? windows[0]?.title ?? running?.appId ?? appId
    readonly property string iconSource: Quickshell.iconPath(entry?.icon || appId, "application-x-executable")

    readonly property bool menuOpen: dash.menu.open && dash.menu.target === root
    readonly property bool wantsLabel: mouse.containsMouse && !menuOpen && !ghost.Drag.active
    onWantsLabelChanged: dash.syncLabel(root)

    property real bounce: 0
    property bool launching: false
    property int cycles: 0
    property bool wasRunning: false

    function startBounce() {
        if (Theme.gameMode)
            return;
        root.wasRunning = root.running !== null;
        root.cycles = 0;
        root.launching = true;
        bounceAnimation.restart();
    }

    function activate(button, modifiers) {
        const openNew = root.entry && root.running && (button === Qt.MiddleButton || (modifiers & Qt.ControlModifier));
        if (root.entry) {
            if (openNew)
                AppsService.openNewWindow(root.entry);
            else
                AppsService.activate(root.entry);
        } else if (root.windows.length > 0) {
            WorkspaceService.focusWindow(root.windows[0]);
        }
        root.dash.hideLabel(root);
        OverviewService.hide();
    }

    function openMenu() {
        dash.menu.openFor(root);
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: root.activate(Qt.LeftButton, 0)
    Keys.onSpacePressed: root.activate(Qt.LeftButton, 0)
    Keys.onMenuPressed: root.openMenu()

    Connections {
        target: AppsService
        function onLaunched(launched) {
            if (root.entry && launched && launched.id === root.entry.id)
                root.startBounce();
        }
    }

    SequentialAnimation {
        id: bounceAnimation
        NumberAnimation {
            target: root
            property: "bounce"
            to: Theme.dashBounceHeight
            duration: Theme.durationDashBounce / 2
            easing.type: Theme.easeOutQuad
        }
        NumberAnimation {
            target: root
            property: "bounce"
            to: 0
            duration: Theme.durationDashBounce / 2
            easing.type: Theme.easeInQuad
        }
        onFinished: {
            root.cycles++;
            const arrived = root.wasRunning || root.running !== null;
            if (root.cycles >= Theme.dashBounceMaxCycles || (root.cycles >= Theme.dashBounceMinCycles && arrived))
                root.launching = false;
            else
                bounceAnimation.restart();
        }
    }

    DashTile {
        id: tile
        x: 0
        y: (root.height - Theme.dashEdgeOffset - height) / 2
        iconSize: root.dash.iconSizeShown
        hovered: mouse.containsMouse
        pressed: mouse.pressed && (mouse.pressedButtons & Qt.LeftButton)
        checked: root.menuOpen
        focused: root.activeFocus

        Icon {
            anchors.fill: parent
            name: root.iconSource
            size: root.dash.iconSizeShown
            symbolic: false
            asynchronous: false
            transform: Translate {
                y: -root.bounce
            }
        }
    }

    Row {
        visible: root.windows.length > 0
        spacing: Theme.dashDotSpacing
        x: (root.width - width) / 2
        y: root.height - Theme.dashEdgeOffset - Theme.dashDotOffset - Theme.dashDotSize

        Repeater {
            model: Math.min(root.windows.length, Theme.dashMaxDots)

            Rectangle {
                width: Theme.dashDotSize
                height: Theme.dashDotSize
                radius: Theme.dashDotSize
                color: Theme.dashDot
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        property point pressPos
        property bool dragged: false

        onPressed: m => {
            pressPos = Qt.point(m.x, m.y);
            dragged = false;
            root.forceActiveFocus();
            if (m.button === Qt.RightButton)
                root.openMenu();
        }
        onPositionChanged: m => {
            if (!pressed || !(pressedButtons & Qt.LeftButton) || !root.entry)
                return;
            if (!ghost.Drag.active) {
                if (Math.hypot(m.x - pressPos.x, m.y - pressPos.y) < Qt.styleHints.startDragDistance)
                    return;
                dragged = true;
                root.dash.dragStarted();
                ghost.Drag.active = true;
            }
            const p = mouse.mapToItem(root.dash.dragLayer, m.x, m.y);
            ghost.x = p.x - ghost.width / 2;
            ghost.y = p.y - ghost.height / 2;
        }
        onReleased: {
            if (ghost.Drag.active) {
                ghost.Drag.drop();
                ghost.Drag.active = false;
                root.dash.dragEnded();
            }
        }
        onClicked: m => {
            if (dragged || m.button === Qt.RightButton)
                return;
            root.activate(m.button, m.modifiers);
        }
    }

    Item {
        id: ghost
        parent: root.dash.dragLayer
        visible: Drag.active || flying
        width: root.dash.iconSize
        height: root.dash.iconSize
        transformOrigin: Item.Center

        property bool flying: false
        function flyTo(center) {
            flyX.to = center.x - width / 2;
            flyY.to = center.y - height / 2;
            flying = true;
            flyAnim.restart();
        }
        ParallelAnimation {
            id: flyAnim
            onFinished: {
                ghost.flying = false;
                ghost.scale = 1;
                ghost.opacity = 1;
            }
            NumberAnimation {
                id: flyX
                target: ghost
                property: "x"
                duration: Theme.gameMode ? 0 : Theme.motionMedium
                easing.type: Theme.easeEmphasized
            }
            NumberAnimation {
                id: flyY
                target: ghost
                property: "y"
                duration: Theme.gameMode ? 0 : Theme.motionMedium
                easing.type: Theme.easeEmphasized
            }
            NumberAnimation {
                target: ghost
                property: "scale"
                to: 0.3
                duration: Theme.gameMode ? 0 : Theme.motionMedium
                easing.type: Theme.easeEmphasized
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Theme.gameMode ? 0 : Theme.motionMedium * 0.5
                }
                NumberAnimation {
                    target: ghost
                    property: "opacity"
                    to: 0
                    duration: Theme.gameMode ? 0 : Theme.motionMedium * 0.5
                    easing.type: Easing.InCubic
                }
            }
        }

        property var entry: root.entry
        property bool favorite: root.favorite

        Drag.source: ghost
        Drag.keys: ["niselle-app"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Icon {
            anchors.fill: parent
            name: root.iconSource
            size: ghost.width
            symbolic: false
        }
    }

    Component.onDestruction: {
        if (ghost.Drag.active) {
            ghost.Drag.active = false;
            root.dash.dragEnded();
        }
    }
}
