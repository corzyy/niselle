import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// Vorschau einer Arbeitsfläche [workspaceThumbnail.js, _workspace-thumbnails.scss]: Hintergrundbild des Monitors,
// darauf die Fenster der Fläche: als Fläche (Layout) und, sobald die Übersicht offen ist, mit einem Standbild des
// Fensters (ScreencopyView, live: false, wie WindowPreview). Die Fläche ist der Monitor
// ohne Panel (Arbeitsbereich, `porthole`). Die leere Fläche am Ende zeigt ein "+". Fenster lassen sich auf die
// Vorschau ziehen (DropArea).
Item {
    id: root

    required property var screen
    // Eintrag aus WorkspaceService.workspacesFor()
    required property var info
    // Verkleinerung gegenüber dem Arbeitsbereich
    required property real viewScale
    // Fenster in der Vorschau zeigen (aus: nur Hintergrund, ohne Aufnahmen)
    property bool showWindows: true
    // Eckenradius der Vorschau
    property real cornerRadius: Theme.radiusThumbnail
    // Hintergrundbild aus dem gemeinsamen Cache laden (gleicher Schlüssel wie WindowPicker), ohne Verzögerung
    property bool sharedWallpaper: false

    signal activated
    signal windowDropped(var toplevel)
    // App-Symbol aus dem App-Grid abgelegt: die App soll auf dieser Fläche starten
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
                // Icon in die Vorschau fliegen lassen (Koordinaten der Ebene, in der es liegt)
                if (event.source.flyTo && event.source.parent)
                    event.source.flyTo(root.mapToItem(event.source.parent, root.width / 2, root.height / 2));
                root.appDropped(event.source.entry);
            }
        }
    }

    // .workspace-thumbnail: Grund, Rand 1 px, Radius 4
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.thumbnailBackground
        border.width: Theme.thumbnailBorder
        border.color: "transparent"
    }

    // Inhalt, mit abgerundeten Ecken beschnitten
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

        // Monitor, nach oben verschoben um die Panelhöhe: sichtbar ist nur der Arbeitsbereich
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
                // Immer asynchron dekodieren, damit der UI-Thread nie durch ein Bild blockiert
                asynchronous: true
                cache: root.sharedWallpaper
            }

            Repeater {
                model: root.showWindows && root.info.workspace ? root.info.workspace.toplevels : null

                // Fenster: Fläche als Grund, darüber ein einzelnes Standbild (blendet ein, sobald es da ist).
                Rectangle {
                    id: win

                    required property var modelData

                    readonly property var at: modelData.lastIpcObject?.at ?? [0, 0]
                    readonly property var size: modelData.lastIpcObject?.size ?? [0, 0]

                    x: (at[0] - root.screen.x) * root.viewScale
                    y: (at[1] - root.screen.y) * root.viewScale
                    width: size[0] * root.viewScale
                    height: size[1] * root.viewScale
                    radius: Math.max(1, Math.min(3, width * 0.1, height * 0.1))
                    color: Theme.thumbnailBg

                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: OverviewService.captureArmed ? (win.modelData.wayland ?? null) : null
                        // Live wie die Fenster-Kacheln (Einstellungen › Erscheinungsbild)
                        live: SettingsService.overviewLiveWindows
                        paintCursor: false
                        // Etwa doppelte Vorschaugröße genügt für scharfe Miniaturen
                        constraintSize: Qt.size(Math.max(1, Math.ceil(win.width * 2)), Math.max(1, Math.ceil(win.height * 2)))
                        opacity: hasContent ? 1 : 0

                        Behavior on opacity {
                            enabled: !Theme.gameMode
                            NumberAnimation {
                                duration: Theme.motionFast
                                easing.type: Theme.easeOut
                            }
                        }
                    }
                }
            }
        }

        // Hervorhebung beim Ziehen über die Vorschau
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

    // Leere Fläche am Ende: "+" (neue Fläche entsteht beim Ablegen oder Wechseln)
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
