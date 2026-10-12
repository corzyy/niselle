import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

// Arbeitsflächen-Leiste der Übersicht [workspaceThumbnail.js: ThumbnailsBox, _workspace-thumbnails.scss].
// Eine Vorschau je Arbeitsfläche des Monitors, am Ende die leere Fläche (dynamisch, mit "+").
// Die Leiste ist immer sichtbar (auch bei nur einer Fläche) und blendet in 200 ms auf. Der Rahmen zur aktiven Fläche gleitet mit.
// Ein Fenster auf eine Vorschau ziehen verschiebt es auf diese Fläche. Mausrad wechselt die Fläche (Overview.qml).
// Klick auf eine Vorschau wechselt auf diese Fläche, ein Klick auf die aktive Fläche schließt die Übersicht
// [workspaceThumbnail.js:505-514 Thumbnail.activate].
Item {
    id: root

    required property var screen
    // Wird von Overview.qml gesetzt: Platz, der für die Leiste zur Verfügung steht (Höhe des Arbeitsbereichs)
    required property real workHeight

    // Stabiles Modell (nach Flächen-ID, mit dem Fensterbereich geteilt): Vorschauen bleiben bei Umbau erhalten,
    // neue wachsen ein, entfernte schrumpfen weg
    required property var wsModel
    // Fensteraufnahmen der Fenstervorschauen (CaptureRegistry), die Leiste nimmt nicht selbst auf
    required property var captures

    readonly property int count: wsModel.count
    // Bei dynamischen Flächen erst ab mehr als zwei Flächen (eine belegte und die leere zählen nicht)
    // [workspaceThumbnail.js: _updateShouldShow, NUM_WORKSPACES_THRESHOLD]. Beim Ziehen eines Fensters immer,
    // damit es sich auf eine andere (oder die leere) Fläche legen lässt.
    readonly property bool shouldShow: count > 2 || OverviewService.windowDragActive

    // Arbeitsbereich des Monitors (Monitor ohne Panel)
    readonly property real portholeWidth: screen.width
    readonly property real portholeHeight: screen.height - Theme.panelHeight

    // vfunc_get_preferred_height / vfunc_allocate [workspaceThumbnail.js:1213-1315]
    readonly property real totalSpacing: (count - 1) * Theme.thumbnailsSpacing
    readonly property real contentWidth: width - 2 * Theme.thumbnailsPadding
    readonly property real prefScale: Math.min(((contentWidth - totalSpacing) / Math.max(1, count)) / portholeWidth, Theme.thumbnailsMaxScale)
    readonly property real naturalHeight: Math.round(portholeHeight * prefScale) + 2 * Theme.thumbnailsPadding
    readonly property real fullHeight: Math.min(naturalHeight, workHeight * Theme.thumbnailsMaxScale)

    property real expand: shouldShow ? 1 : 0
    Behavior on expand {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Theme.easeOut
        }
    }

    visible: expand > 0
    implicitHeight: Math.round(fullHeight * expand)
    // Nicht während Öffnen/Schließen: sonst wandert die Fensterfläche (pickerBox) pro Frame mit
    Behavior on implicitHeight {
        enabled: OverviewService.shown && (!OverviewService.animating) && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    readonly property real availW: (contentWidth - totalSpacing) / Math.max(1, count)
    readonly property real availH: fullHeight - 2 * Theme.thumbnailsPadding
    readonly property real thumbScale: Math.min(availW / portholeWidth, availH / portholeHeight)

    // Größe und Zahl der Vorschauen gleiten mit der Position (gleiche Kurve wie WorkspaceModel.position),
    // damit Zuwachs oder Wegfall einer Fläche die Leiste weich umbaut, statt sie springen zu lassen.
    property real shownScale: thumbScale
    property real shownCount: count
    Behavior on shownScale {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }
    Behavior on shownCount {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    readonly property real thumbFullHeight: Math.round(portholeHeight * shownScale)
    readonly property real thumbWidth: Math.round(thumbFullHeight * (portholeWidth / portholeHeight))
    readonly property real pitch: thumbWidth + Theme.thumbnailsSpacing
    readonly property real rowWidth: shownCount * pitch - Theme.thumbnailsSpacing
    readonly property real rowX: Math.round((width - rowWidth) / 2)

    // Aktive Vorschau: Rechteck in Fensterkoordinaten, an das die Fenster im App-Grid schrumpfen
    readonly property real activeThumbX: rowX + wsModel.position * pitch
    readonly property rect activeRect: {
        // Auf den Übersichts-Fortschritt zugreifen, damit das Rechteck beim Ein-/Ausblenden mitwandert
        void OverviewService.progress;
        const p = root.mapToItem(null, root.activeThumbX, Theme.thumbnailsPadding);
        return Qt.rect(p.x, p.y, root.thumbWidth, root.thumbFullHeight);
    }
    // Nur gebraucht, wenn die Fenster ins App-Grid schrumpfen; sonst würde das Rechteck in jedem Frame der Öffnungs-
    // animation neu berechnet und alle Seiten mitziehen
    Binding {
        target: OverviewService
        property: "activeThumbnailRect"
        value: root.activeRect
        when: OverviewService.appsShown || OverviewService.appsProgress > 0
        restoreMode: Binding.RestoreNone
    }

    // Inhalt wird bei fortschreitendem Aufblenden von oben her sichtbar, Höhe zählt nur für die Überdeckung
    Item {
        id: strip
        x: 0
        y: Theme.thumbnailsPadding
        width: parent.width
        height: root.thumbFullHeight
        opacity: root.expand

        Repeater {
            model: wsModel.model

            WorkspaceThumbnail {
                id: thumb

                required property int wsId
                required property bool gone

                readonly property var entry: wsModel.infoFor(wsId)

                // Platz in der Reihe: gleitet bei Umbau (Flächen kommen/gehen) an die neue Stelle
                readonly property real targetSlot: wsModel.slotFor(wsId)
                property real slot: targetSlot
                Behavior on slot {
                    enabled: OverviewService.shown && !Theme.gameMode
                    NumberAnimation {
                        duration: Theme.motionSlow
                        easing.type: Theme.easeOut
                    }
                }

                // Neue Vorschau wächst aus der Mitte ein, entfernte schrumpft weg (nur bei sichtbarer Übersicht)
                property real appear: 0
                Behavior on appear {
                    enabled: OverviewService.shown && !Theme.gameMode
                    NumberAnimation {
                        duration: Theme.motionFast
                        easing.type: Theme.easeOut
                    }
                }
                readonly property real wanted: gone ? 0 : 1
                onWantedChanged: appear = wanted
                Component.onCompleted: appear = wanted

                screen: root.screen
                info: entry
                captures: root.captures
                viewScale: root.shownScale
                // Das in Overview.qml vorgeladene Hintergrundbild mitbenutzen (gleicher Cache-Schlüssel),
                // damit die Leiste beim Öffnen nicht erst neu dekodieren muss.
                sharedWallpaper: true
                x: root.rowX + Math.round(slot * root.pitch)
                width: root.thumbWidth
                height: root.thumbFullHeight
                opacity: appear
                scale: 1
                visible: appear > 0.01
                enabled: !gone

                // Klick auf die aktive Fläche: zurück zur Hauptansicht; sonst auf die Fläche wechseln
                // [workspaceThumbnail.js:505-514 Thumbnail.activate]
                onActivated: {
                    if (info.active)
                        OverviewService.hide();
                    else
                        WorkspaceService.switchTo(info.id, root.screen);
                }
                onAppDropped: entry => {
                    if (!info.workspace)
                        WorkspaceService.focusMonitor(root.screen);
                    WorkspaceService.launchOn(entry, info.id);
                }
                onWindowDropped: toplevel => {
                    if (toplevel.workspace && toplevel.workspace.id === info.id)
                        return;
                    if (!info.workspace)
                        WorkspaceService.focusMonitor(root.screen);
                    WorkspaceService.moveWindow(toplevel, info.id, false);
                }
            }
        }

        // .workspace-thumbnail-indicator: Rahmen 3 px in Akzentfarbe, außen um die aktive Vorschau
        Rectangle {
            x: root.rowX + Math.round(wsModel.position * root.pitch) - Theme.thumbnailIndicatorBorder
            y: -Theme.thumbnailIndicatorBorder
            width: root.thumbWidth + 2 * Theme.thumbnailIndicatorBorder
            height: root.thumbFullHeight + 2 * Theme.thumbnailIndicatorBorder
            radius: Theme.radiusThumbnailIndicator
            color: "transparent"
            border.width: Theme.thumbnailIndicatorBorder
            border.color: Theme.accentColor
        }
    }
}
