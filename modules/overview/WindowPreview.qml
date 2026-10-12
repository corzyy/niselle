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
    // Aufnahmen des Overview-Fensters (CaptureRegistry): die Leiste zeigt diese Aufnahme mit, statt eine eigene zu machen
    property var captures: null
    // Live-Stream erlaubt (sichtbare Seite); sonst bleibt das zuletzt aufgenommene Standbild stehen
    property bool streaming: false
    // Fenster einer aktiven Fläche: neues Standbild schon beim Öffnen, nicht erst nach der Animation
    property bool activeWorkspace: false
    // Aufnahme aktiv; kurz aus, um einen abgebrochenen Aufnahme-Kontext neu anzulegen
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

    // Symbolgröße: Anteil der kürzeren Kachelseite, nach oben begrenzt, damit ein großes Fenster
    // (progress 0) kein riesiges Symbol zeigt. Gerastert wird nur einmal in der Größe der Endfläche (`iconPxFinal`),
    // während der Animation skaliert das Symbol nur: eine neue Größe ließe das Bild in jedem Frame neu rastern.
    // Bindungen an width/height laufen in jedem Animationsframe: nur auswerten, solange Symbol bzw. Beiwerk sichtbar sind
    function _iconPx() {
        return Math.max(16, Math.min(Math.min(width, height) * 0.42, Theme.windowIconSize * 1.8));
    }
    readonly property real iconPxFinal: captureWidth > 0 && captureHeight > 0 ? Math.max(16, Math.min(Math.min(captureWidth, captureHeight) * 0.42, Theme.windowIconSize * 1.8)) : Theme.windowIconSize

    // Vergrößerung beim Überfahren: (größte Seite + 2 × 5 px) / größte Seite [windowPreview.js:331-335]
    readonly property real activeScale: {
        if (!shown)
            return 1;
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
                easing.type: Theme.easeOut
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

        // Standbild des Fensters über dem Kachel-Grund. Die Aufnahme bleibt auch bei geschlossener Übersicht
        // bestehen: beim Öffnen ist sofort das letzte Bild da (GNOME zeigt ab dem ersten Frame Fenster-Klone),
        // OverviewService.refreshCaptures fordert dann ein neues an. Nur die allererste Aufnahme blendet ein.
        ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: root.captureEnabled ? (root.toplevel?.wayland ?? null) : null
            // Live-Stream der Fenster (Einstellungen › Erscheinungsbild) statt eines einzelnen Standbilds:
            // erst nach der Öffnungsanimation (captureArmed) und nur auf sichtbaren Seiten.
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

        // Schlägt eine Aufnahme fehl (Hyprland meldet einen Fehler, etwa beim Start der Shell oder wenn sich das Fenster
        // während der Kopie in der Größe ändert), endet ihr Kontext still und für immer: `stopped` kommt dabei nicht
        // zuverlässig. Deshalb wird der Kontext nach jedem Schließen neu angelegt, solange die Übersicht unsichtbar ist
        // (kein Ruckeln): er nimmt sofort ein frisches Bild auf, und beim nächsten Öffnen ist ein aktuelles da.
        // Fenster ohne Bild bekommen zusätzlich beim Öffnen einen neuen Kontext.
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
        // Beim Beenden der Shell die Aufnahme freigeben, solange die Wayland-Verbindung noch steht: sonst räumt
        // Quickshell den Aufnahme-Kontext erst nach dem Trennen ab und stürzt dabei ab (Absturzbericht bei jedem Neustart)
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
            // Neues Standbild beim Öffnen; zeigt solange das vorige. Ohne Bild: Kontext neu anlegen.
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

        // App-Symbol und Titel, mittig — ÜBER dem Standbild. Sie bleiben auch nach dem Eintreffen des
        // Standbilds noch eine Haltedauer lang voll sichtbar und decken so den Wechsel zum Screenshot
        // ab; erst danach blenden sie weich aus. Ohne die Haltezeit flackerte der Übergang.
        Column {
            id: tileContent
            anchors.centerIn: parent
            width: parent.width
            spacing: Math.round(root.height * 0.05)
            // Ausgeblendet ganz unsichtbar: sonst würde die Spalte bei jeder Größenänderung neu gesetzt
            visible: root.width > 24 && root.height > 24 && opacity > 0

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
    readonly property real heightIncrease: container.scale === 1 ? 0 : Math.floor(height * (container.scale - 1) / 2)
    readonly property real widthIncrease: container.scale === 1 ? 0 : Math.floor(width * (container.scale - 1) / 2)

    // Schließen-Knopf (.window-close): Mitte auf der oberen rechten Ecke
    Rectangle {
        id: close
        visible: opacity > 0
        opacity: root.shown ? 1 : 0
        width: Theme.windowCloseSize
        height: Theme.windowCloseSize
        // Nur bei sichtbarem Knopf an die Kachelgröße gebunden (die ändert sich in jedem Animationsframe)
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
