import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import qs
import qs.services

// Fensterbereich der Übersicht [workspace.js, workspacesView.js]: Karussell der Arbeitsflächen dieses Monitors.
// Jede Fläche ist eine WorkspacePage mit den Fenstern, angeordnet wie in GNOME (Zeilen nach Seitenverhältnis,
// kleine Lücken, siehe WindowLayout.js); die aktive liegt in der Mitte, die Nachbarn ragen seitlich herein.
// Der Picker liefert nur Boxen und Fortschritt, WorkspaceModel die stabile Flächenliste und die Gleitposition.
//
// Gehört in `windowsSlot`, als Fläche über das ganze Overview-Fenster (Overview.qml). Der Inhalt arbeitet in Koordinaten des Overview-Fensters (nicht des Slots), damit Fenster beim
// Öffnen von ihrer echten Position in den Platz der Vorschau gleiten: Position = lerp(Original, Platz, progress).
// Die Vorschauen entstehen erst, solange die Übersicht sichtbar ist (Loader), die Aufnahme läuft nur dann.
Item {
    id: root

    required property var screen
    // Fenster in voller Größe (progress 0) und Platz der Vorschauen (progress 1) in Fensterkoordinaten
    required property rect hiddenBox
    required property rect pickerBox
    required property real progress
    required property Item dragLayer
    required property real windowWidth
    required property real windowHeight
    // App-Grid wird geöffnet: Fenster schrumpfen in die aktive Arbeitsflächen-Vorschau oben
    required property real appsProgress
    required property bool primary
    // Gemeinsame Flächenliste (Overview.qml) und Aufnahmen je Fenster (CaptureRegistry)
    required property var wsModel
    required property var captures

    // Ziel-Rechteck der Schrumpf-Animation; 0 auf Nebenmonitoren (dort gibt es keine Leiste)
    readonly property rect flyTarget: OverviewService.activeThumbnailRect
    readonly property real fly: primary ? appsProgress : 0

    // Arbeitsflächen-Hintergrund: seitlicher Einzug, wächst mit dem Fortschritt
    readonly property real sideInset: Theme.workspaceSideInset * progress
    // Seitenverhältnis des Monitors, damit der Hintergrund wie ein verkleinerter Bildschirm aussieht
    readonly property real workspaceAspect: screen && screen.height > 0 ? screen.width / screen.height : 16 / 9

    // Rechteck des Hintergrunds: vom vollen Bildschirm (progress 0) in die Vorschaufläche (progress 1).
    // Start- und Endfläche haben beide das Monitor-Seitenverhältnis, deshalb ist die Bewegung eine reine,
    // gleichmäßige Skalierung ohne Sprung am Anfang – die Arbeitsfläche „morpht“ in ihre Vorschau.
    // [workspace.js:942-1021]
    readonly property rect workspaceBox: {
        const x = pickerBox.x * progress + sideInset;
        const y = pickerBox.y * progress;
        const availW = windowWidth + (pickerBox.width - windowWidth) * progress - 2 * sideInset;
        const availH = windowHeight + (pickerBox.height - windowHeight) * progress;
        let w = availW;
        let h = w / workspaceAspect;
        if (h > availH) {
            h = availH;
            w = h * workspaceAspect;
        }
        return Qt.rect(x + (availW - w) / 2, y + (availH - h) / 2, w, h);
    }

    // Stabile Flächenliste mit der gleitenden Mittelposition (WorkspaceModel, mit der Leiste geteilt)
    readonly property real neighborGap: Math.max(Theme.workspaceSideInset, Math.round(workspaceBox.width * 0.04))
    readonly property real slideStep: workspaceBox.width + neighborGap
    Component.onCompleted: Hyprland.refreshToplevels()

    // Der Slot gibt die Fläche vor; die Höhe zählt nicht für das Layout der Übersicht
    implicitHeight: 0

    // Größe von Titel samt Rand (.window-caption), für den Platz unter den Vorschauen
    Text {
        id: probe
        visible: false
        text: "Ag"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }
    readonly property real captionHeight: probe.implicitHeight + 2 * (Theme.tooltipPaddingV + Theme.tooltipBorderWidth)

    // Beiwerk, das über die Vorschau hinausragt [windowPreview.js:215-247]
    readonly property real topOversize: Theme.windowCloseSize / 2 + Theme.windowActiveSizeInc
    readonly property real bottomOversize: (1 - Theme.windowIconOverlap) * Theme.windowIconSize + Theme.windowActiveSizeInc
    readonly property real sideOversize: Theme.windowCloseSize / 2 + Theme.windowActiveSizeInc
    readonly property real oversize: Math.max(topOversize, bottomOversize, sideOversize)

    // Endfläche der Vorschau (progress = 1). Stabil während der Öffnungsanimation und daher als
    // Aufnahme-Auflösung geeignet: die Fenster werden nur einmal in Vorschaugröße aufgenommen,
    // nicht pro Frame bei sich ändernder Slot-Größe.
    readonly property rect finalWorkspaceBox: {
        const inset = Theme.workspaceSideInset;
        const availW = pickerBox.width - 2 * inset;
        const availH = pickerBox.height;
        let w = availW;
        let h = w / workspaceAspect;
        if (h > availH) {
            h = availH;
            w = h * workspaceAspect;
        }
        return Qt.rect(pickerBox.x + inset + (availW - w) / 2, pickerBox.y + (availH - h) / 2, w, h);
    }
    readonly property rect finalWindowBox: {
        const pad = Math.round(finalWorkspaceBox.height * Theme.windowPickerPaddingRatio);
        return Qt.rect(finalWorkspaceBox.x + pad, finalWorkspaceBox.y + pad, Math.max(0, finalWorkspaceBox.width - 2 * pad), Math.max(0, finalWorkspaceBox.height - 2 * pad));
    }

    // ───────── Gemeinsamer Arbeitsflächen-Hintergrund ─────────
    // Das Hintergrundbild mit abgerundeten Ecken wird einmal in Endgröße (finalWorkspaceBox) als Textur gerendert und nur
    // bei Änderungen neu gezeichnet. Jede Seite zeigt diese Textur als einfaches Rechteck (ShaderEffect ohne eigenen
    // Shader), statt selbst zwei bildschirmgroße Ebenen (Bild und Maske) zu rendern.
    // [workspace.js:942-1021 WorkspaceBackground, BACKGROUND_CORNER_RADIUS_PIXELS]
    readonly property string wallpaperSource: WallpaperService.sourceFor(screen ? screen.name : "")
    readonly property Item wallpaperTexture: wallpaperSource !== "" ? wallpaperRounded : null

    Item {
        id: wallpaperPlain
        visible: false
        width: Math.max(1, Math.round(root.finalWorkspaceBox.width))
        height: Math.max(1, Math.round(root.finalWorkspaceBox.height))
        layer.enabled: true

        Image {
            anchors.fill: parent
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            // Gleicher Cache-Schlüssel wie das vorgeladene Bild in Overview.qml; asynchron, damit kein Decode blockiert
            asynchronous: true
            cache: true
        }
    }
    Item {
        id: wallpaperMask
        visible: false
        width: wallpaperPlain.width
        height: wallpaperPlain.height
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.workspaceCornerRadius
        }
    }
    MultiEffect {
        id: wallpaperRounded
        visible: false
        width: wallpaperPlain.width
        height: wallpaperPlain.height
        source: wallpaperPlain
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: wallpaperMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        layer.enabled: true
        layer.smooth: true
    }

    // ───────── Arbeitsflächen ─────────
    // Eine Seite je Fläche; Klick auf eine Nachbarfläche wechselt dorthin (WorkspacePage)
    Repeater {
        model: root.wsModel.model

        WorkspacePage {
            picker: root
            keyed: root.wsModel
        }
    }
}
