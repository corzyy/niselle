import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services
import "WindowLayout.js" as WindowLayout

// Eine Arbeitsfläche im Fensterbereich der Übersicht [workspace.js: Workspace]: Hintergrundbild des Monitors mit den
// Fenstern der Fläche, angeordnet wie in GNOME (WindowLayout.js). Jede Fläche des Karussells ist eine solche Seite,
// auch die Nachbarn: beim Gleiten behalten die Fenster ihre Anordnung, statt beim Wechsel von echter Lage ins Layout
// zu springen. Die Seite gehört zu einer Fläche (ID) und bleibt dabei, auch wenn sich Reihenfolge oder Anzahl ändern.
//
// Koordinaten: Die Seite füllt das Overview-Fenster und wird um den Versatz zur Mitte verschoben (`x`). Innen gelten
// Fensterkoordinaten, als wäre sie die mittlere Seite (`picker.workspaceBox`).
Item {
    id: page

    // WindowPicker: Boxen, Fortschritt, Mittelposition
    required property var picker
    required property var keyed
    // Zeile aus WorkspaceModel
    required property int wsId
    required property bool gone

    readonly property var info: keyed?.infoFor(wsId) ?? null
    readonly property var workspace: info?.workspace ?? null
    readonly property bool isActive: wsId === keyed?.activeId

    // Platz im Karussell (Index in der Anzeigereihenfolge), gleitet bei Umbau
    readonly property real targetSlot: keyed?.slotFor(wsId) ?? 0
    property real slot: targetSlot
    Behavior on slot {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    // Abstand zur Mitte in Flächenbreiten (gebrochen während des Gleitens)
    readonly property real dist: slot - (keyed?.position ?? 0)
    readonly property real absDist: Math.abs(dist)

    // Nur die aktive Fläche schrumpft beim App-Grid in ihre Vorschau; die anderen blenden aus
    readonly property real fly: isActive ? picker.fly : 0
    readonly property rect box: picker.workspaceBox
    // Hintergrund: vom großen Platz (box) in die aktive Vorschau (flyTarget)
    // Ohne App-Grid (fly = 0) direkt `box`, ohne das Ziel zu lesen
    readonly property rect shownBox: fly > 0 ? Qt.rect(
        box.x + (picker.flyTarget.x - box.x) * fly,
        box.y + (picker.flyTarget.y - box.y) * fly,
        box.width + (picker.flyTarget.width - box.width) * fly,
        box.height + (picker.flyTarget.height - box.height) * fly) : box

    // Mitte voll deckend, Nachbarn blenden mit der Entfernung und dem Fortschritt ein; entfernte Seiten blenden aus.
    // Nebenmonitore haben keine Leiste und zeigen nur die aktive Fläche.
    readonly property real centerness: Math.max(0, 1 - absDist)
    readonly property real sideOpacity: 0.8 * Math.max(0, Math.min(1, 2.2 - absDist)) * picker.progress * (1 - picker.fly) * (picker.primary ? 1 : 0)
    opacity: (centerness + (1 - centerness) * sideOpacity) * (gone ? 0 : 1)
    Behavior on opacity {
        enabled: page.gone && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Theme.easeOut
        }
    }

    // Nachbarflächen sind etwas kleiner als die aktive [workspacesView.js: WORKSPACE_INACTIVE_SCALE = 0.94]
    readonly property real inactiveScale: 1 - (1 - Theme.workspaceInactiveScale) * Math.min(1, absDist) * picker.progress
    transform: Scale {
        origin.x: page.shownBox.x + page.shownBox.width / 2
        origin.y: page.shownBox.y + page.shownBox.height / 2
        xScale: page.inactiveScale
        yScale: page.inactiveScale
    }

    x: dist * picker.slideStep * (1 - fly)
    y: 0
    width: picker.windowWidth
    height: picker.windowHeight
    // Höhere Seiten (Mitte) über den Nachbarn: Beiwerk der Fenster (Schließen-Knopf) ragt über den Rand
    z: -absDist

    // Immer sichtbar (außer entfernt): Deckkraft 0 überspringt der Renderer ohnehin. Ein Wechsel von `visible`, wenn
    // eine Nachbarseite beim Öffnen hereinkommt, baute ihren Teilbaum mitten in der Animation für den Renderer auf.
    visible: !gone || opacity > 0.01

    // Alle Seiten behalten ihre Fenstervorschauen (und deren Aufnahme): beim Gleiten entsteht und verschwindet nichts,
    // und die Arbeitsflächen-Leiste zeigt dieselben Aufnahmen. Live-Stream (Einstellung) nur für sichtbare Seiten.
    readonly property bool near: isActive || (picker.primary && absDist < 1.6)

    // ───────── Fenster ─────────
    // Ohne die Fenster, die gerade auf eine andere Fläche gezogen wurden
    readonly property var windows: {
        void WorkspaceService.departingRevision;
        return workspace ? workspace.toplevels.values.filter(t => !WorkspaceService.isDeparting(t)) : [];
    }

    // Fenstergeometrie auf dem Monitor, aus der Hyprland-IPC (aktualisiert bei Fensterereignissen)
    readonly property var rawGeometry: {
        void WorkspaceService.geometryRevision;
        const ox = picker.screen?.x ?? 0;
        const oy = picker.screen?.y ?? 0;
        return windows.map(t => {
            const o = t.lastIpcObject;
            const at = o?.at ?? [0, 0];
            const size = o?.size ?? [0, 0];
            return {
                address: t.address,
                x: at[0] - ox,
                y: at[1] - oy,
                width: size[0],
                height: size[1]
            };
        });
    }
    // Übernommen nur bei einer echten Änderung: jede IPC-Aktualisierung liefert neue Objekte, auch wenn sich nichts bewegt
    // hat, und das Layout (WindowLayout.compute) soll nicht bei jedem Ereignis neu laufen.
    property var geometry: []
    onRawGeometryChanged: _takeGeometry()
    Component.onCompleted: _takeGeometry()
    function _takeGeometry() {
        const next = rawGeometry;
        const prev = geometry;
        let same = next.length === prev.length;
        for (let i = 0; same && i < next.length; i++) {
            const a = next[i];
            const b = prev[i];
            same = a.address === b.address && a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
        }
        if (!same)
            geometry = next;
    }

    // Layout der Fenster in der Endfläche (progress = 1). Die Vorschauen gleiten per progress von ihrer echten Position
    // dorthin; das Layout wird nur bei Änderungen der Fenster berechnet, nicht pro Animationsframe.
    // Platz je Fenster, nach Adresse (die Reihenfolge der Repeater-Delegates entspricht nicht der von `windows`)
    function _byAddress(list) {
        const map = {};
        for (let i = 0; i < geometry.length; i++)
            map[geometry[i].address] = list[i];
        return map;
    }
    readonly property var slotByAddress: _byAddress(captureSlots)
    readonly property var geometryByAddress: _byAddress(geometry)
    readonly property var captureSlots: WindowLayout.compute(geometry, {
        monitorHeight: picker.windowHeight,
        workarea: picker.finalWorkspaceBox,
        container: picker.finalWindowBox,
        spacing: Theme.windowPickerSpacing,
        oversize: picker.oversize,
        bottomOverlap: Theme.windowIconTitleSpacing + picker.captionHeight,
        monitorBottomFree: picker.windowHeight - (picker.finalWorkspaceBox.y + picker.finalWorkspaceBox.height),
        maxScale: Theme.windowPreviewMaxScale,
        scaleWeight: Theme.layoutScaleWeight,
        spaceWeight: Theme.layoutSpaceWeight
    })

    // ───────── Arbeitsflächen-Hintergrund ─────────
    // Das aktuelle Hintergrundbild des Monitors hinter den Fenstern der Vorschau [workspace.js:942-1021 WorkspaceBackground].
    // Deckend (kein Einblenden): die Fläche skaliert sichtbar vom vollen Bildschirm in die Vorschau. Die Textur mit den
    // abgerundeten Ecken rendert WindowPicker einmal für alle Seiten; hier wird sie nur noch gezeichnet.
    ShaderEffect {
        x: page.shownBox.x
        y: page.shownBox.y
        width: page.shownBox.width
        height: page.shownBox.height
        visible: picker.wallpaperTexture !== null
        property variant source: picker.wallpaperTexture
    }

    // Klick auf eine Nachbarfläche wechselt dorthin, ein Fenster darauf ablegen verschiebt es [workspacesView.js]
    Item {
        x: page.shownBox.x
        y: page.shownBox.y
        width: page.shownBox.width
        height: page.shownBox.height
        enabled: !page.isActive && !page.gone

        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["niselle-window"]
            onDropped: event => {
                if (!event.source || !event.source.toplevel)
                    return;
                event.accept(Qt.MoveAction);
                const toplevel = event.source.toplevel;
                if (toplevel.workspace && toplevel.workspace.id === page.wsId)
                    return;
                if (!page.workspace)
                    WorkspaceService.focusMonitor(picker.screen);
                WorkspaceService.moveWindow(toplevel, page.wsId, false);
            }
        }

        // Hervorhebung beim Ziehen über die Fläche
        Rectangle {
            anchors.fill: parent
            radius: Theme.workspaceCornerRadius * picker.progress
            visible: drop.containsDrag
            color: Theme.thumbnailDropOverlay
        }

        MouseArea {
            anchors.fill: parent
            onClicked: WorkspaceService.switchTo(page.wsId, picker.screen)
        }
    }

    // ───────── Fensterkacheln ─────────
    Repeater {
        model: page.workspace ? page.workspace.toplevels : null

        WindowPreview {
            id: preview

            required property var modelData

            readonly property var geom: page.geometryByAddress[modelData.address] ?? {
                "x": 0,
                "y": 0,
                "width": 0,
                "height": 0
            }
            readonly property var slot: page.slotByAddress[modelData.address] ?? geom
            // Auf eine andere Fläche gezogen: verschwindet sofort, die übrigen Fenster rücken nach
            readonly property bool departed: WorkspaceService.isDeparting(modelData)
            opacity: departed ? 0 : 1
            scale: departed ? 0.6 : 1
            visible: opacity > 0
            enabled: !departed && !page.gone
            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }
            Behavior on scale {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }

            // Platz mit Ausgleichsanimation bei Änderungen (neues/geschlossenes Fenster) [workspace.js:467-475]
            property real sx: slot.x
            property real sy: slot.y
            property real sw: slot.width
            property real sh: slot.height
            readonly property bool animateSlot: !OverviewService.animating && OverviewService.shown
            Behavior on sx {
                enabled: (preview.animateSlot) && !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeEmphasized
                }
            }
            Behavior on sy {
                enabled: (preview.animateSlot) && !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeEmphasized
                }
            }
            Behavior on sw {
                enabled: (preview.animateSlot) && !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeEmphasized
                }
            }
            Behavior on sh {
                enabled: (preview.animateSlot) && !Theme.gameMode
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easeEmphasized
                }
            }

            toplevel: modelData
            captures: picker.captures
            streaming: page.near
            activeWorkspace: page.isActive
            dragLayer: picker.dragLayer
            // Ferne, unsichtbare Seiten folgen dem Fortschritt nicht: ihre Vorschauen rechnen sonst in jedem Frame mit
            progress: page.near ? picker.progress : 1
            // Aufnahme-Auflösung = Endgröße des Slots (stabil während der Animation)
            captureWidth: slot.width
            captureHeight: slot.height

            // Platz der Vorschau bei geöffneter Übersicht
            readonly property real openX: geom.x + (sx - geom.x) * progress
            readonly property real openY: geom.y + (sy - geom.y) * progress
            readonly property real openW: geom.width + (sw - geom.width) * progress

            // Beim App-Grid schrumpft die ganze Fläche in die aktive Vorschau: jedes Fenster behält seine relative
            // Lage und Größe im Hintergrund (box → flyTarget). Ohne App-Grid (fly = 0) wird der Zielteil gar nicht
            // ausgewertet: die Bindungen hängen dann nur am Fortschritt, nicht zusätzlich an Leiste und Hintergrund.
            x: page.fly > 0 ? openX + (picker.flyTarget.x + (openX - page.box.x) / Math.max(1, page.box.width) * picker.flyTarget.width - openX) * page.fly : openX
            y: page.fly > 0 ? openY + (picker.flyTarget.y + (openY - page.box.y) / Math.max(1, page.box.height) * picker.flyTarget.height - openY) * page.fly : openY
            readonly property real shownW: page.fly > 0 ? openW + (openW / Math.max(1, page.box.width) * Math.max(1, picker.flyTarget.width) - openW) * page.fly : openW

            // Die Kachel behält ihre Endgröße (Platz im Layout) und wird nur skaliert, wie die Fenster-Klone in GNOME:
            // eine neue Größe in jedem Frame ließ alle Kinder (Grund, Aufnahme, Symbol, Mausfläche) jedes Mal neu
            // anordnen. Das Layout erhält das Seitenverhältnis, daher genügt ein gemeinsamer Faktor; bei
            // progress = 1 ist er genau 1 (scharfe Darstellung).
            width: Math.max(1, sw)
            height: Math.max(1, sh)
            transform: Scale {
                xScale: preview.shownW / Math.max(1, preview.sw)
                yScale: xScale
            }

            onSelected: {
                WorkspaceService.focusWindow(modelData);
                OverviewService.hide();
            }
        }
    }
}
