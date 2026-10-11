import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import "../overview/WindowLayout.js" as WindowLayout

// Bildschirmfoto-/Aufnahme-Overlay eines Monitors (GNOME screenshotUI.js, Maße aus gnome-shell-dark.css):
//   Bereich    abgedunkelter Bildschirm (0,5), Ausschnitt mit 2 px weißem Rand und runden Eckgriffen (24 px)
//   Bildschirm je Monitor eine Fläche: 0,5 dunkel, 0,3 beim Überfahren, 0,7 beim Drücken, gewählt: klar mit weißem Rand
//   Fenster    opaker Grund #222226 mit Vorschauen der Fenster, gewähltes mit Akzentrahmen und Haken
// Das Bedienfeld (ScreenshotPanel) und der Schließen-Knopf liegen auf dem Monitor, auf dem die Oberfläche geöffnet wurde.
// Zustand und Aufnahme: ScreenshotService.
PanelWindow {
    id: root

    readonly property string mode: ScreenshotService.mode
    readonly property bool isPanelScreen: ScreenshotService.panelScreen === (screen ? screen.name : "")
    readonly property bool isActive: ScreenshotService.activeScreen === (screen ? screen.name : "")
    readonly property int handleTolerance: 12
    readonly property real minSize: 8

    // Auswahl in lokalen Koordinaten dieses Monitors
    readonly property rect localSel: Qt.rect(ScreenshotService.selection.x - screen.x, ScreenshotService.selection.y - screen.y, ScreenshotService.selection.width, ScreenshotService.selection.height)

    visible: ScreenshotService.open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-screenshot"
    WlrLayershell.keyboardFocus: root.isPanelScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible)
        keys.forceActiveFocus()

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ScreenshotService.close()
        Keys.onReturnPressed: ScreenshotService.captureCurrent()
        Keys.onEnterPressed: ScreenshotService.captureCurrent()
        Keys.onSpacePressed: ScreenshotService.captureCurrent()
    }

    // ---- Bereich ---------------------------------------------------------------------------------------------------

    Item {
        id: areaMode
        anchors.fill: parent
        visible: root.mode === "selection"

        readonly property rect hole: root.isActive ? root.localSel : Qt.rect(0, 0, 0, 0)
        readonly property color shade: Qt.rgba(0, 0, 0, 0.5)

        // Abdunkelung: vier Flächen um den Ausschnitt
        Rectangle {
            x: 0
            y: 0
            width: root.width
            height: areaMode.hole.y
            color: areaMode.shade
        }
        Rectangle {
            x: 0
            y: areaMode.hole.y + areaMode.hole.height
            width: root.width
            height: root.height - y
            color: areaMode.shade
        }
        Rectangle {
            x: 0
            y: areaMode.hole.y
            width: areaMode.hole.x
            height: areaMode.hole.height
            color: areaMode.shade
        }
        Rectangle {
            x: areaMode.hole.x + areaMode.hole.width
            y: areaMode.hole.y
            width: root.width - x
            height: areaMode.hole.height
            color: areaMode.shade
        }

        // .screenshot-ui-area-indicator-selection: 2 px weißer Rand, außen um den Ausschnitt
        Rectangle {
            visible: root.isActive
            x: areaMode.hole.x - 2
            y: areaMode.hole.y - 2
            width: areaMode.hole.width + 4
            height: areaMode.hole.height + 4
            color: "transparent"
            border.width: 2
            border.color: "white"
        }

        // .screenshot-ui-area-selector-handle: weiße Kreise (24 px) mit Schatten an den vier Ecken
        Repeater {
            model: root.isActive ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []

            Item {
                required property var modelData
                width: 24
                height: 24
                x: root.localSel.x + root.localSel.width * modelData[0] - width / 2
                y: root.localSel.y + root.localSel.height * modelData[1] - height / 2

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    anchors.topMargin: -1
                    anchors.bottomMargin: -3
                    radius: width
                    color: Qt.rgba(0, 0, 0, 0.2)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width
                    color: "white"
                }
            }
        }
    }

    // Griff unter dem Zeiger: "move", Kante/Ecke ("n", "se", …) oder "" (neue Auswahl)
    function hit(px, py) {
        const r = root.localSel, t = root.handleTolerance;
        const inX = px >= r.x - t && px <= r.x + r.width + t;
        const inY = py >= r.y - t && py <= r.y + r.height + t;
        const vert = inX ? (Math.abs(py - r.y) <= t ? "n" : (Math.abs(py - (r.y + r.height)) <= t ? "s" : "")) : "";
        const horiz = inY ? (Math.abs(px - r.x) <= t ? "w" : (Math.abs(px - (r.x + r.width)) <= t ? "e" : "")) : "";
        if (vert !== "" || horiz !== "")
            return vert + horiz;
        return px > r.x && px < r.x + r.width && py > r.y && py < r.y + r.height ? "move" : "";
    }
    function cursorFor(h) {
        switch (h) {
        case "n":
        case "s":
            return Qt.SizeVerCursor;
        case "e":
        case "w":
            return Qt.SizeHorCursor;
        case "nw":
        case "se":
            return Qt.SizeFDiagCursor;
        case "ne":
        case "sw":
            return Qt.SizeBDiagCursor;
        case "move":
            return Qt.SizeAllCursor;
        }
        return Qt.CrossCursor;
    }

    // Auswahl aus zwei beliebigen Ecken (lokal) setzen: sortiert, auf den Monitor begrenzt
    function setSelection(x0, y0, x1, y1, enforceMin) {
        let l = Math.max(0, Math.min(x0, x1)), r = Math.min(width, Math.max(x0, x1));
        let t = Math.max(0, Math.min(y0, y1)), b = Math.min(height, Math.max(y0, y1));
        if (enforceMin) {
            r = Math.max(r, l + root.minSize);
            b = Math.max(b, t + root.minSize);
            if (r > width) {
                r = width;
                l = r - root.minSize;
            }
            if (b > height) {
                b = height;
                t = b - root.minSize;
            }
        }
        ScreenshotService.selection = Qt.rect(Math.round(l + screen.x), Math.round(t + screen.y), Math.round(r - l), Math.round(b - t));
    }

    MouseArea {
        id: areaMouse
        anchors.fill: parent
        enabled: root.mode === "selection"
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.cursorFor(drag.handle !== "" ? drag.handle : (root.isActive ? root.hit(mouseX, mouseY) : ""))

        // Ziehzustand: Griff und Ausgangslage (lokal)
        QtObject {
            id: drag
            property string handle: ""
            property bool creating: false
            property real px: 0
            property real py: 0
            property rect start: Qt.rect(0, 0, 0, 0)
        }

        onPressed: m => {
            if (!root.isActive) {
                // Anderer Monitor: Auswahl beginnt hier
                ScreenshotService.activeScreen = root.screen.name;
                drag.handle = "";
            } else {
                drag.handle = root.hit(m.x, m.y);
            }
            drag.px = m.x;
            drag.py = m.y;
            drag.creating = drag.handle === "";
            if (drag.creating) {
                drag.start = Qt.rect(m.x, m.y, 0, 0);
                drag.handle = "se";
                root.setSelection(m.x, m.y, m.x, m.y, false);
            } else {
                drag.start = root.localSel;
            }
        }
        onPositionChanged: m => {
            if (!pressed || drag.handle === "")
                return;
            const s = drag.start, dx = m.x - drag.px, dy = m.y - drag.py;
            if (drag.handle === "move") {
                const x = Math.max(0, Math.min(root.width - s.width, s.x + dx));
                const y = Math.max(0, Math.min(root.height - s.height, s.y + dy));
                root.setSelection(x, y, x + s.width, y + s.height, false);
                return;
            }
            let l = s.x, t = s.y, r = s.x + s.width, b = s.y + s.height;
            if (drag.handle.indexOf("w") >= 0)
                l += dx;
            if (drag.handle.indexOf("e") >= 0)
                r += dx;
            if (drag.handle.indexOf("n") >= 0)
                t += dy;
            if (drag.handle.indexOf("s") >= 0)
                b += dy;
            root.setSelection(l, t, r, b, !drag.creating);
        }
        onReleased: {
            drag.handle = "";
            drag.creating = false;
        }
    }

    // ---- Bildschirm ------------------------------------------------------------------------------------------------

    Rectangle {
        id: screenMode
        anchors.fill: parent
        visible: root.mode === "screen"
        color: root.isActive ? "transparent" : (screenMouse.pressed ? Qt.rgba(0, 0, 0, 0.7) : (screenMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(0, 0, 0, 0.5)))
        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: 200
                easing.type: Theme.easeOut
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: "white"
            opacity: root.isActive ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: 200
                    easing.type: Theme.easeOut
                }
            }
        }

        MouseArea {
            id: screenMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ScreenshotService.activeScreen = root.screen.name
        }
    }

    // ---- Fenster ---------------------------------------------------------------------------------------------------

    Rectangle {
        id: windowMode
        anchors.fill: parent
        visible: root.mode === "window"
        color: "#222226"

        // Fenster dieses Monitors (Mittelpunkt liegt darauf), lokal zum Monitor
        readonly property var monitorWindows: ScreenshotService.windows.filter(c => {
            const cx = c.x + c.w / 2, cy = c.y + c.h / 2;
            return cx >= root.screen.x && cx < root.screen.x + root.width && cy >= root.screen.y && cy < root.screen.y + root.height;
        })
        // .screenshot-ui-window-selector-window-container: 100 px Rand, auf dem Bedienfeld-Monitor unten 200 px
        readonly property rect container: Qt.rect(100, 100, Math.max(0, root.width - 200), Math.max(0, root.height - 100 - (root.isPanelScreen ? 200 : 100)))
        readonly property var slots: WindowLayout.compute(monitorWindows.map(c => ({
                        x: c.x - root.screen.x,
                        y: c.y - root.screen.y,
                        width: c.w,
                        height: c.h
                    })), {
            monitorHeight: root.height,
            workarea: container,
            container: container,
            spacing: Theme.windowPickerSpacing,
            oversize: 6,
            bottomOverlap: 0,
            monitorBottomFree: 0,
            maxScale: Theme.windowPreviewMaxScale,
            scaleWeight: Theme.layoutScaleWeight,
            spaceWeight: Theme.layoutSpaceWeight
        })

        // Klick ins Leere wählt nichts; Rechtsklick schließt nicht
        Repeater {
            model: windowMode.visible ? windowMode.monitorWindows : []

            ScreenshotWindowTile {
                required property var modelData
                required property int index
                window: modelData
                slot: windowMode.slots[index] ?? Qt.rect(0, 0, 0, 0)
                checked: ScreenshotService.windowAddress === modelData.address
                onClicked: ScreenshotService.selectWindow(modelData)
            }
        }
    }

    // ---- Bedienfeld und Schließen-Knopf (GNOME: Primärmonitor) -----------------------------------------------------

    ScreenshotPanel {
        visible: root.isPanelScreen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(4 * Theme.fontSizeBase * 96 / 72)
    }

    // .screenshot-ui-close-button: Symbolknopf oben rechts, 12 px Rand, Schatten
    Item {
        visible: root.isPanelScreen
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        width: closeButton.width
        height: closeButton.height

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            radius: Theme.radiusPill
            color: Qt.rgba(0, 0, 0, 0.2)
        }
        IconButton {
            id: closeButton
            icon: Quickshell.shellPath("assets/icons/preview-close-symbolic.svg")
            padding: 6
            bg: Theme.osdBg
            fg: Theme.osdFg
            onClicked: ScreenshotService.close()
        }
    }
}
