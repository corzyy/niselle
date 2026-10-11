import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// Kachel eines Fensters in der Übersicht.
// Der Elternteil legt Position und Größe fest (x, y, width, height = Fläche der Vorschau).
//
// Grund ist der neutrale Kachel-Grund mit App-Symbol und Titel — sofort da, ohne Aufnahme, damit beim
// Öffnen nichts fehlt (kein Blitz). Darüber blendet ein einzelnes Standbild des Fensters
// (ScreencopyView, live: false) ein, sobald es da ist: man sieht also ein Frame des Programms, ohne
// auf die Aufnahme warten zu müssen und ohne Live-Stream (kostet nur eine Kopie je Fenster).
//
// Beiwerk:
//   Schließen-Knopf an der oberen rechten Ecke: erscheint beim Überfahren, die Kachel wächst dabei
//   je Richtung um 5 px [windowPreview.js:318-346]
// Klick holt das Fenster nach vorn (selected), Mittelklick und Schließen-Knopf schließen es,
// Ziehen löst ein Ablegen auf einer Arbeitsflächen-Vorschau aus (Drag-Quelle mit `toplevel`).
Item {
    id: root

    required property var toplevel
    // Ebene über allem, in der die gezogene Kachel liegt
    required property Item dragLayer
    // 0 = Fenster in Originalgröße, 1 = Übersicht komplett
    property real progress: 1
    // Zielgröße des Standbilds (Endfläche, progress = 1). Stabil, damit die Aufnahme nur einmal
    // entsteht und nicht pro Frame mit der Animation neu angefordert wird.
    property real captureWidth: 0
    property real captureHeight: 0

    signal selected

    readonly property alias container: container
    readonly property bool overlayShown: shown
    readonly property bool dragging: ghost.Drag.active

    property bool shown: false

    readonly property var entry: AppsService.entryForWindow(toplevel)
    readonly property string windowClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property string title: toplevel?.title || entry?.name || windowClass
    readonly property string iconSource: Quickshell.iconPath(entry?.icon || windowClass.toLowerCase(), "application-x-executable")

    // Symbolgröße: Anteil der kürzeren Kachelseite, nach oben begrenzt, damit ein großes Fenster
    // (progress 0) kein riesiges Symbol zeigt.
    readonly property real iconPx: Math.max(16, Math.min(Math.min(width, height) * 0.42, Theme.windowIconSize * 1.8))

    // Vergrößerung beim Überfahren: (größte Seite + 2 × 5 px) / größte Seite [windowPreview.js:331-335]
    readonly property real activeScale: {
        const orig = Math.max(width, height);
        return orig > 0 ? (orig + 2 * Theme.windowActiveSizeInc) / orig : 1;
    }

    // Etwas höher stapeln, solange Beiwerk sichtbar ist
    z: shown ? 1 : 0

    // ───────── Anzeige ─────────

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
                easing.type: Theme.easeSpring
                easing.overshoot: Theme.springOvershoot
            }
        }

        // Neutraler Grund statt Aufnahme: abgerundete Fläche in der Kachelfarbe
        Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Math.min(Theme.radiusThumbnail, root.width * 0.06, root.height * 0.06))
            color: Theme.thumbnailBg
            border.width: Theme.thumbnailBorder
            border.color: "transparent"
        }

        // Einzelnes Standbild des Fensters (live: false) über dem Kachel-Grund. Es blendet erst ein,
        // wenn ein Bild da ist — der Grund darunter deckt in der Zwischenzeit, so entsteht beim Öffnen
        // kein leerer Frame (der Grund ist sofort da, das Bild folgt weich).
        ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: OverviewService.captureArmed ? (root.toplevel?.wayland ?? null) : null
            // Live-Stream der Fenster (Einstellungen › Erscheinungsbild) statt eines einzelnen Standbilds.
            // Der Stream läuft nur, solange captureArmed gesetzt ist (Übersicht sichtbar); beim Schließen
            // wird captureSource null und die Aufnahme endet.
            live: SettingsService.overviewLiveWindows
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

        // App-Symbol und Titel, mittig — ÜBER dem Standbild. Sie bleiben auch nach dem Eintreffen des
        // Standbilds noch eine Haltedauer lang voll sichtbar und decken so den Wechsel zum Screenshot
        // ab; erst danach blenden sie weich aus. Ohne die Haltezeit flackerte der Übergang.
        Column {
            id: tileContent
            anchors.centerIn: parent
            width: parent.width
            spacing: Math.round(root.height * 0.05)
            visible: root.width > 24 && root.height > 24

            // Logo erst nach der Haltedauer ausblenden (nicht sofort, wenn das Bild da ist)
            property bool logoHidden: false
            opacity: logoHidden ? 0 : 1
            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }

            // Kurze Haltezeit: Symbol und Standbild überblenden sich, statt dass das Symbol lange über dem Fenster steht
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
                height: glyph.implicitHeight

                Icon {
                    id: glyph
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.iconSource
                    symbolic: false
                    size: root.iconPx
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

    // Hover für die Kachel selbst; Klicks und Ziehen
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

    // ───────── Beiwerk ─────────

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

    // Verschiebung des Beiwerks, wenn die Kachel wächst [windowPreview.js:413-427]
    readonly property real heightIncrease: Math.floor(height * (container.scale - 1) / 2)
    readonly property real widthIncrease: Math.floor(width * (container.scale - 1) / 2)

    // Schließen-Knopf (.window-close): Mitte auf der oberen rechten Ecke
    Rectangle {
        id: close
        visible: opacity > 0
        opacity: root.shown ? 1 : 0
        width: Theme.windowCloseSize
        height: Theme.windowCloseSize
        x: root.width - width / 2 + root.widthIncrease
        y: -height / 2 - root.heightIncrease
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

    // ───────── Ziehen ─────────
    // Die gezogene Kachel ist höchstens 256 px groß, halbtransparent und hängt mittig am Zeiger [windowPreview.js:15-25]

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

        // Die bereits gezeichnete Kachel wiederverwenden: keine zweite Aufnahme, sofort da
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

        // Sanftes Einblenden/Ausblenden beim Greifen und Loslassen
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

    // Zeiger bleibt während des Ziehens an diese Ebene gebunden und meldet auch Koordinaten außerhalb davon:
    // liegt der Loslass-Punkt (global) auf einem anderen Monitor, wandert das Fenster auf dessen aktive Fläche.
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
