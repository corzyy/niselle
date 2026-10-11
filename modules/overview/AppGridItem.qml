import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

// Ein Eintrag des App-Grids (.overview-tile / .app-folder) [appDisplay.js: AppIcon, FolderIcon].
// Zeigt entweder eine App (Icon + Titel + Laufpunkt) oder einen Ordner (2×2-Vorschau der ersten vier Apps,
// gefüllte Kachel). Klick startet die App bzw. öffnet den Ordner, Rechtsklick öffnet das App-Menü,
// Ziehen löst ein Ablegen (Schlüssel "niselle-app") aus. Das Raster legt Zellgröße und Icongröße fest.
//
// `controller` (AppGrid oder AppFolderDialog) liefert dragLayer, aktiviert Einträge und öffnet das Menü.
Item {
    id: root

    required property var controller
    // Eintrag aus AppGridService.model.byId: { id, kind: "app"|"folder", name, entry, apps }
    required property var item
    // Apps lassen sich aufeinander zu einem Ordner legen (nicht im Ordner-Dialog)
    property bool nestFolders: true
    property int pageIndex: 0
    property int position: 0
    property real iconSize: Theme.appGridIconSizes[0]
    property real cellSize: iconSize + 2 * Theme.overviewTilePadding
    // Einblenden beim Öffnen des App-Grids: Fortschritt 0 → 1 und Staffelung (0 = zuerst, 1 = zuletzt).
    // Die Kachel fährt von `revealOrigin` (Mitte des „Apps anzeigen“-Knopfs) an ihren Platz und blendet gestaffelt auf.
    // Der Ordner-Dialog setzt beides nicht, dort bleibt die Kachel voll sichtbar (reveal = 1).
    property real revealProgress: 1
    property real revealDelay: 0
    property point revealOrigin: Qt.point(0, 0)
    readonly property real reveal: {
        if (root.revealProgress >= 1)
            return 1;
        if (root.revealProgress <= 0)
            return 0;
        const window_ = Math.max(0.0001, 1 - Theme.appGridRevealSpread);
        return Math.max(0, Math.min(1, (root.revealProgress - root.revealDelay * Theme.appGridRevealSpread) / window_));
    }

    // Auslaufkurve mit leichtem Überschwingen: die Kachel setzt sich federnd an ihren Platz
    readonly property real settle: {
        const t = root.reveal - 1;
        return 1 + 2.2 * t * t * t + 1.2 * t * t;
    }

    // Kacheln fahren aus dem Stapel unten auseinander und wachsen dabei auf; jede mit eigenem Verlauf
    transform: [
        Translate {
            x: root.reveal >= 1 ? 0 : (root.revealOrigin.x - root.x - root.width / 2) * (1 - root.settle)
            y: root.reveal >= 1 ? 0 : (root.revealOrigin.y - root.y - root.height / 2) * (1 - root.settle)
        },
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: 1 - Theme.appGridRevealScale * (1 - root.settle)
            yScale: xScale
        }
    ]

    // Kacheln blenden gestaffelt von oben nach unten auf
    opacity: Theme.appGridRevealOpacity + (1 - Theme.appGridRevealOpacity) * root.reveal

    readonly property bool isFolder: item ? item.kind === "folder" : false
    readonly property var entry: item ? item.entry : null
    readonly property var running: !isFolder && entry ? AppsService.runningFor(entry) : null
    readonly property var windows: running ? running.windows : []
    readonly property bool isRunning: running !== null
    readonly property string iconSource: entry ? (entry.icon || "application-x-executable") : ""
    readonly property string label: item ? item.name : ""

    readonly property bool menuOpen: root.controller && root.controller.menu ? (root.controller.menu.open && root.controller.menu.target === root) : false
    readonly property bool dropTarget: drop.containsDrag
    property bool pressed: false

    // Wird dieses Icon gerade gezogen (Geist aktiv)
    readonly property bool dragging: ghost.Drag.active

    // Ziehen einer App auf die Mitte einer anderen App: Vorschau des entstehenden Ordners
    // [appDisplay.js: AppIcon._canAccept/createFolderIcon]. `drop.drag` gilt nur während des Ziehens.
    readonly property var draggedItem: drop.containsDrag ? drop.drag.source : null
    readonly property var draggedEntry: root.draggedItem ? root.draggedItem.entry : null
    readonly property bool folderDropPreview: {
        if (!root.nestFolders || root.isFolder || !root.item || root.item.kind !== "app" || !root.draggedItem)
            return false;
        if (root.draggedItem.gridKind !== "app" || root.draggedItem.gridId === root.item.id)
            return false;
        const x = drop.drag.x;
        return x > Theme.appGridDividerLeeway && x < root.width - Theme.appGridDividerLeeway;
    }

    width: cellSize
    height: cellSize

    function activate(button, modifiers) {
        if (root.isFolder) {
            root.controller.openFolder(root.item.id, root.mapToItem(null, root.width / 2, root.height / 2));
            return;
        }
        const openNew = root.isRunning && (button === Qt.MiddleButton || (modifiers & Qt.ControlModifier));
        if (openNew)
            AppsService.openNewWindow(root.entry);
        else
            AppsService.activate(root.entry);
        OverviewService.hide();
    }

    function openMenu() {
        if (!root.isFolder && root.controller.menu)
            root.controller.menu.openFor(root);
    }

    // Vorschau eines Ordners: 2×2-Raster der ersten vier Apps, je 0.4 der Icongröße [appDisplay.js: createFolderIcon]
    Component {
        id: folderPreview

        Item {
            width: root.iconSize
            height: root.iconSize

            readonly property real sub: Math.floor(Theme.appFolderSubiconFraction * root.iconSize)
            readonly property var apps: root.item ? root.item.apps : []

            Repeater {
                model: 4

                Icon {
                    required property int index
                    readonly property int col: index % 2
                    readonly property int row: Math.floor(index / 2)
                    x: (col + 0.5) * root.iconSize / 2 - parent.sub / 2
                    y: (row + 0.5) * root.iconSize / 2 - parent.sub / 2
                    visible: index < parent.apps.length
                    name: index < parent.apps.length ? (parent.apps[index].icon || "application-x-executable") : ""
                    size: parent.sub
                    symbolic: false
                }
            }
        }
    }

    // Vorschau beim Ziehen auf eine andere App: Ziel- und gezogene App im Ordnermuster
    Component {
        id: dragFolderPreview

        Item {
            width: root.iconSize
            height: root.iconSize

            readonly property real sub: Math.floor(Theme.appFolderSubiconFraction * root.iconSize)
            readonly property var apps: {
                const out = [];
                if (root.entry)
                    out.push(root.entry);
                if (root.draggedEntry)
                    out.push(root.draggedEntry);
                return out;
            }

            Repeater {
                model: 4

                Icon {
                    required property int index
                    readonly property int col: index % 2
                    readonly property int row: Math.floor(index / 2)
                    x: (col + 0.5) * root.iconSize / 2 - parent.sub / 2
                    y: (row + 0.5) * root.iconSize / 2 - parent.sub / 2
                    visible: index < parent.apps.length
                    name: index < parent.apps.length ? (parent.apps[index].icon || "application-x-executable") : ""
                    size: parent.sub
                    symbolic: false
                }
            }
        }
    }

    AppTile {
        id: tile
        anchors.fill: parent
        icon: root.isFolder || root.folderDropPreview ? "" : root.iconSource
        customIcon: root.isFolder ? folderPreview : (root.folderDropPreview ? dragFolderPreview : null)
        label: root.label
        iconSize: root.iconSize
        running: root.isRunning
        raised: root.isFolder
        hovered: mouse.containsMouse
        pressed: root.pressed
        checked: root.menuOpen || root.folderDropPreview
        dropTarget: root.dropTarget
        focused: root.activeFocus
        bg: Theme.systemBase
        expandOnHover: !root.controller.dragging
        opacity: root.dragging ? Theme.appIconDragSourceOpacity : 1
    }

    // Einfügemarke am Rand der Kachel, wenn das Ablegen sortiert statt einen Ordner zu bilden
    readonly property bool insertMark: {
        if (!root.draggedItem || root.draggedItem.gridId === root.item.id || root.folderDropPreview)
            return false;
        const x = drop.drag.x;
        const edge = x <= Theme.appGridDividerLeeway || x >= root.width - Theme.appGridDividerLeeway;
        const nests = root.nestFolders && root.draggedItem.gridKind === "app";
        return edge || !nests;
    }
    Rectangle {
        visible: root.insertMark && drop.containsDrag
        width: 3
        radius: 1.5
        height: root.iconSize
        y: Theme.overviewTilePadding
        x: drop.drag.x < root.width / 2 ? 0 : root.width - width
        color: Theme.accentColor
    }

    // Gezogenes Icon: Kachel in Icongröße am Zeiger [appDisplay.js: BaseIcon.getDragActorSource]
    Item {
        id: ghost
        parent: root.controller && root.controller.dragLayer ? root.controller.dragLayer : null
        visible: Drag.active || flying
        width: root.iconSize
        height: root.iconSize
        transformOrigin: Item.Center

        // Auf eine Arbeitsflächen-Vorschau abgelegt: das Icon fliegt in die Vorschau, schrumpft und blendet aus
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

        // Von DropArea/Dash gelesen
        property var entry: root.entry
        property string gridId: root.item ? root.item.id : ""
        property string gridKind: root.item ? root.item.kind : ""
        property bool favorite: false

        Drag.source: ghost
        Drag.keys: ["niselle-app"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Loader {
            anchors.fill: parent
            sourceComponent: root.isFolder ? folderPreview : null
        }
        Icon {
            anchors.fill: parent
            visible: !root.isFolder
            name: root.iconSource
            size: ghost.width
            symbolic: false
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        property point pressPos
        property bool dragged: false

        onPressed: m => {
            pressPos = Qt.point(m.x, m.y);
            dragged = false;
            root.pressed = true;
            root.forceActiveFocus();
            if (m.button === Qt.RightButton)
                root.openMenu();
        }
        onPositionChanged: m => {
            if (!pressed || !(pressedButtons & Qt.LeftButton))
                return;
            if (!ghost.Drag.active) {
                if (Math.hypot(m.x - pressPos.x, m.y - pressPos.y) < Qt.styleHints.startDragDistance)
                    return;
                dragged = true;
                root.controller.dragStarted();
                ghost.Drag.active = true;
            }
            // Geist dem Zeiger nachführen (wie DashItem); ohne das bliebe das gezogene Icon an seiner Stelle
            const p = mouse.mapToItem(root.controller.dragLayer, m.x, m.y);
            ghost.x = p.x - ghost.width / 2;
            ghost.y = p.y - ghost.height / 2;
            if (root.controller.dragMoved)
                root.controller.dragMoved(p.x, p.y);
        }
        onReleased: {
            root.pressed = false;
            if (ghost.Drag.active) {
                ghost.Drag.drop();
                ghost.Drag.active = false;
                root.controller.dragEnded();
            }
        }
        onClicked: m => {
            if (dragged || m.button === Qt.RightButton)
                return;
            root.activate(m.button, m.modifiers);
        }
    }

    // Ablegeziel: Ordner nimmt Apps auf, ein Icon nimmt Umsortieren bzw. (Mitte) ein neues Ordnerpaar an
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["niselle-app"]
        onDropped: dropEvent => root.controller.dropOnItem(root, dropEvent.source, dropEvent.x)
    }

    Keys.onReturnPressed: root.activate(Qt.LeftButton, 0)
    Keys.onSpacePressed: root.activate(Qt.LeftButton, 0)
    Keys.onMenuPressed: root.openMenu()

    Component.onDestruction: {
        if (ghost.Drag.active) {
            ghost.Drag.active = false;
            root.controller.dragEnded();
        }
    }
}
