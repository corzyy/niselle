import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import qs.modules.dash

// Übersicht (Overview) [overview.js, overviewControls.js]: Vollbild-Layer über allen Fenstern, eine pro Monitor.
// Den Fortschritt (0 → 1, 250 ms, EASE_OUT_SINE beim Öffnen, EASE_OUT_QUAD beim Schließen) liefert OverviewService.
//
// Aufbau auf dem primären Monitor von oben nach unten [overviewControls.js:151-243]:
//   searchSlot      Suchfeld, direkt unter dem Panel
//   thumbnailsSlot  Arbeitsflächen-Leiste
//   windowsSlot     Fensterbereich (füllt den Rest, wächst beim Öffnen aus der Arbeitsfläche auf `pickerBox`)
//   dashSlot        Dash am unteren Rand
// Nebenmonitore zeigen nur den Fensterbereich (80 %) [workspacesView.js:27, 695-697].
// Suche, Arbeitsflächen-Leiste und Dash gleiten beim Öffnen ein (Suche, Leiste von oben, Dash von unten).
//
// Fensterbereich: WindowPicker (Vorschauen der aktiven Arbeitsfläche), Arbeitsflächen-Leiste: WorkspaceThumbnails (nur primärer
// Monitor). Beide werden nur geladen, solange die Übersicht sichtbar ist, damit keine Aufnahme im Hintergrund läuft.
// Mausrad wechselt die Fläche, gezogene Fenster liegen in `dragOverlay` über allem.
//
// Unterkomponenten: Kind des jeweiligen Slots, z. B. `searchSlot { SearchBar { screen: root.screen } }` in dieser Datei.
// Die Slot-Höhe folgt der `implicitHeight` des Inhalts (siehe OverviewSlot).
// Fensterbereich: `hiddenBox` (Fenster in voller Größe) und `pickerBox` (Fenster als Vorschau) geben Start und Ziel
// der Skalierung an, `OverviewService.progress` die Zwischenstellung.
//
// Tasten: Esc schließt, Super (allein gedrückt und losgelassen) schließt [overview.js: overlay-key]. Kinder, die Esc selbst
// brauchen (aktive Suche), nehmen das Ereignis in ihrem Keys-Handler an. Klick ins Leere schließt.
PanelWindow {
    id: root

    readonly property real progress: OverviewService.progress
    readonly property bool primary: OverviewService.isPrimary(screen)

    // Für das Layout zählt die (stabile) Bildschirmgröße, nicht die Fenstergröße: beim Ein-/Ausblenden
    // legt Quickshell die Fläche neu an und das PanelWindow meldet kurzzeitig width/height = 0. Hingen
    // Vorschau-Maße und Aufnahmegröße davon ab, wurden die Aufnahmen während des Öffnens mehrfach
    // verworfen (constraintSize 0/NaN) und die Fenstervorschauen flackerten.
    readonly property real screenWidth: root.screen ? root.screen.width : root.width
    readonly property real screenHeight: root.screen ? root.screen.height : root.height

    // Eine Flächenliste und eine Aufnahme je Fenster für Fensterbereich und Arbeitsflächen-Leiste dieses Monitors
    WorkspaceModel {
        id: screenWorkspaces
        screen: root.screen
    }
    CaptureRegistry {
        id: captureRegistry
    }

    // Einmal geöffnetes App-Grid bleibt geladen (instant beim nächsten Mal)
    property bool appGridWarm: false

    // Bereiche, die Unterkomponenten füllen
    readonly property alias searchSlot: searchSlot
    readonly property alias thumbnailsSlot: thumbnailsSlot
    readonly property alias windowsSlot: windowsSlot
    readonly property alias dashSlot: dashSlot
    readonly property alias dragOverlayItem: dragOverlay

    // ───────── Layout (Koordinaten im Fenster) ─────────
    // Arbeitsfläche beginnt unter dem Panel; Nebenmonitore haben keine Top Bar und reichen bis zur Oberkante
    readonly property real workTop: primary ? Theme.panelHeight : 0
    readonly property real workHeight: screenHeight - workTop
    readonly property real spacing: Math.round(workHeight * Theme.overviewSpacingRatio)

    readonly property real searchHeight: primary ? searchSlot.implicitHeight : 0
    readonly property real dashHeight: primary ? Math.min(dashSlot.implicitHeight, Math.round(workHeight * Theme.overviewDashMaxHeightRatio)) : 0
    readonly property real thumbnailsHeight: primary ? thumbnailsSlot.implicitHeight : 0
    // Unterkante des Inhaltsbereichs (über dem Dash) für die Suchergebnisse
    readonly property real workBottom: workTop + workHeight - dashHeight - spacing

    readonly property real thumbnailsY: workTop + searchHeight + Math.round(spacing * Theme.overviewThumbnailsSpacingTop)
    readonly property real thumbnailsGap: thumbnailsHeight > 0 ? Math.round(spacing * Theme.overviewThumbnailsSpacingBottom) : 0

    // Fenster in voller Größe (ControlsState.HIDDEN)
    readonly property rect hiddenBox: Qt.rect(0, workTop, screenWidth, workHeight)
    // Fenster als Vorschau (ControlsState.WINDOW_PICKER)
    readonly property rect pickerBox: {
        if (!primary) {
            const padX = Math.round((1 - Theme.overviewSecondaryScale) * screenWidth / 2);
            const padY = Math.round((1 - Theme.overviewSecondaryScale) * workHeight / 2);
            return Qt.rect(padX, workTop + padY, screenWidth - 2 * padX, workHeight - 2 * padY);
        }
        const y = thumbnailsY + thumbnailsHeight + thumbnailsGap;
        return Qt.rect(0, y, screenWidth, workTop + workHeight - dashHeight - spacing - y);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Die Layer-Fläche bleibt eingebunden (leer, ohne Inhalt), solange die Übersicht zu ist. Das Anlegen und Einbinden
    // der Fläche beim Öffnen dauerte rund 200 ms plus einen ersten, schweren Frame von rund 100 ms: erst danach kam das
    // erste Bild, und die Animation war bis dahin schon verbraucht. Das gilt für alle Monitore, denn alle Fenster der
    // Shell teilen sich einen UI-Thread: auch ein Nebenmonitor mit Vollbild-Video verzögerte die Übersicht auf dem
    // primären.
    // Ausgeblendet wird sie nur noch im Gamemode und bei Vollbild-Fenstern auf diesem Monitor, wenn Hyprland dort direkt
    // ausgibt (Scanout), reißen lässt oder VRR nutzt (OverviewService.scanoutSensitive): eine Ebene über dem Spiel oder
    // Video verhindert das. Ohne diese Optionen kostet die leere Ebene darüber nichts Spürbares.
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool fullscreenActive: {
        void WorkspaceService.geometryRevision;
        void WorkspaceService.revision;
        return !!monitor?.activeWorkspace?.lastIpcObject?.hasfullscreen;
    }
    readonly property bool open: OverviewService.visible
    visible: open || (!Theme.gameMode && !(OverviewService.scanoutSensitive && fullscreenActive))
    // Der Streifen der Top Bar nimmt keine Mausereignisse: sie gehen an die Leiste darunter (oder darüber, bei Vollbild).
    // Geschlossen bleibt nur ein Pixel in der unteren rechten Ecke: eine leere Maske würde als „keine Maske“ gelten und
    // die ganze Fläche finge die Maus.
    mask: Region {
        x: root.open ? 0 : root.screenWidth - 1
        y: root.open ? root.workTop : root.screenHeight - 1
        width: root.open ? root.screenWidth : 1
        height: root.open ? root.workHeight : 1
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-overview"
    // Nur der primäre Monitor nimmt die Tastatur. Nicht Exclusive: Hyprland leitet den Zeiger sonst auf die
    // exklusive Ebene um, und auf den Nebenmonitoren reagiert keine Maus mehr. OnDemand bekommt den Fokus beim
    // Einblenden, solange der Zeiger auf diesem Monitor liegt.
    WlrLayershell.keyboardFocus: primary && OverviewService.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Unscharfes Hintergrundbild (mit aktivem Blur): das aktuelle Wallpaper dieses Monitors, blendet mit der Übersicht ein
    Item {
        anchors.fill: parent
        anchors.topMargin: root.workTop
        clip: true
        // Nicht an der Deckkraft: ein Wechsel von `visible` beim Öffnen legte die Unschärfe-Ebene neu an.
        // Deckt doppelt so schnell wie der Fortschritt: um die schrumpfende Arbeitsfläche sollen die echten Fenster
        // darunter nur kurz durchscheinen (Hyprland verwischt hinter der Übersicht nicht mehr, siehe BlurService).
        visible: Theme.blur && !Theme.gameMode
        opacity: Math.min(1, root.progress * 2)

        Image {
            y: -root.workTop
            width: root.width
            height: root.height
            source: WallpaperService.awwwSourceFor(root.screen.name)
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: 1
            }
        }
    }

    // Abgedunkelter Hintergrund; Klick ins Leere schließt
    // Der Streifen der Top Bar bleibt frei: die Leiste liegt in der Top-Ebene darunter und dunkelt sich selbst ab
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.workTop
        color: Theme.overviewBg
        opacity: (Theme.blur && !Theme.gameMode ? 0.35 : Theme.overviewScrimOpacity) * root.progress

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (!OverviewService.animating)
                    OverviewService.hide();
            }
        }
    }

    // Hintergrundbild vorladen, damit der Arbeitsflächen-Hintergrund beim Öffnen der Übersicht sofort da ist
    // (derselbe Cache-Schlüssel wie das Bild in WindowPicker.qml, deshalb ohne sourceSize)
    Image {
        visible: false
        width: 1
        height: 1
        source: WallpaperService.awwwSourceFor(root.screen.name)
        cache: true
    }

    FocusScope {
        id: keys

        // Super wurde allein gedrückt (keine andere Taste dazwischen)
        property bool superArmed: false

        anchors.fill: parent
        // Geschlossen nur durchsichtig, nicht unsichtbar und nicht gesperrt: Wechsel von `visible` oder `enabled` laufen
        // durch den ganzen Baum (alle Seiten, Vorschauen, Dash, App-Grid) und kosteten das erste Bild der Animation.
        // Eingaben erreichen die geschlossene Übersicht ohnehin nicht (Maske: 1 px, kein Tastaturfokus).
        opacity: root.open ? 1 : 0
        focus: OverviewService.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                OverviewService.dismiss();
                event.accepted = true;
            } else if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                if (!event.isAutoRepeat)
                    keys.superArmed = true;
                event.accepted = true;
            } else {
                keys.superArmed = false;
            }
        }
        Keys.onReleased: event => {
            if (event.key !== Qt.Key_Super_L && event.key !== Qt.Key_Super_R)
                return;
            if (keys.superArmed)
                OverviewService.hide();
            keys.superArmed = false;
            event.accepted = true;
        }

        // Fensterbereich: wächst beim Öffnen vom Vollbild-Fenster zur Vorschau
        OverviewSlot {
            id: windowsSlot
            x: root.hiddenBox.x + (root.pickerBox.x - root.hiddenBox.x) * root.progress
            y: root.hiddenBox.y + (root.pickerBox.y - root.hiddenBox.y) * root.progress
            width: root.hiddenBox.width + (root.pickerBox.width - root.hiddenBox.width) * root.progress
            height: root.hiddenBox.height + (root.pickerBox.height - root.hiddenBox.height) * root.progress
            // Über dem App-Grid, damit die Fenster beim Öffnen sichtbar in die Vorschau oben schrumpfen
            z: OverviewService.appsProgress > 0 ? 5 : 0
            // Wechsel zum App-Grid blendet die Fenster aus (nur primär); die Suche liegt als Overlay darüber
            opacity: root.primary ? 1 - Math.max(0, Math.min(1, (OverviewService.appsProgress - 0.6) / 0.4)) : 1
            // Nicht an der Deckkraft festmachen: ein Wechsel von `enabled` läuft durch alle Kinder (hier: alle Seiten
            // und Vorschauen) und kostete mitten in der Animation einen ganzen Frame
            enabled: OverviewService.appsProgress < 0.5 && OverviewService.searchProgress < 0.5

            // Fensterkoordinaten statt Slot-Koordinaten: die Fenster gleiten von ihrer echten Position in die Vorschau.
            // Immer geladen (Pre-Warm): der Aufbau kostet beim Öffnen keine Zeit. Aufgenommen wird trotzdem nur,
            // solange die Übersicht sichtbar ist; danach bleibt das letzte Standbild je Fenster stehen (WindowPreview).
            // Beschnitten am Streifen der Top Bar: bei progress 0 deckt der Hintergrund sonst den ganzen Bildschirm
            // und damit die Leiste ab (sie liegt in der Top-Ebene unter der Übersicht).
            Item {
                x: -windowsSlot.x
                y: root.workTop - windowsSlot.y
                width: root.screenWidth
                height: root.screenHeight - root.workTop
                clip: true

                Loader {
                    y: -root.workTop
                    width: root.screenWidth
                    height: root.screenHeight
                    active: true

                    sourceComponent: WindowPicker {
                        screen: root.screen
                        hiddenBox: root.hiddenBox
                        pickerBox: root.pickerBox
                        progress: root.progress
                        appsProgress: OverviewService.appsProgress
                        primary: root.primary
                        dragLayer: dragOverlay
                        windowWidth: root.screenWidth
                        windowHeight: root.screenHeight
                        wsModel: screenWorkspaces
                        captures: captureRegistry
                    }
                }
            }
        }

        // App-Grid: gleiche Fläche wie die Fenstervorschau, blendet mit `appsProgress` herüber [overviewControls.js: APP_GRID]
        // Nur auf dem primären Monitor.
        OverviewSlot {
            id: appsSlot
            // Ohne App-Grid (unsichtbar) nicht dem Fortschritt folgen: sonst liefen Slot und skaliertes Grid in jedem Frame mit
            readonly property real p: OverviewService.appsProgress > 0 || OverviewService.appsShown ? root.progress : 1
            x: root.hiddenBox.x + (root.pickerBox.x - root.hiddenBox.x) * p
            y: root.hiddenBox.y + (root.pickerBox.y - root.hiddenBox.y) * p
            width: root.hiddenBox.width + (root.pickerBox.width - root.hiddenBox.width) * p
            height: root.hiddenBox.height + (root.pickerBox.height - root.hiddenBox.height) * p
            opacity: Math.min(1, OverviewService.appsProgress * 2.5)
            visible: root.primary && OverviewService.appsProgress > 0
            enabled: root.primary && OverviewService.appsProgress > 0.5 && OverviewService.searchProgress < 0.5

            // Immer geladen, sobald das App-Grid einmal benutzt wurde (Pre-Warm): danach instant.
            // Feste Größe (Größe des geöffneten Slots) und Mitführen per Skalierung: würde das Grid mit dem Slot
            // mitwachsen, liefen Moduswahl und Neuberechnung aller Seiten und Kacheln in jedem Bild der Animation
            // (Ruckeln beim Schließen aus dem App-Grid). Bei progress = 1 ist der Skalierungsfaktor 1.
            Loader {
                width: root.pickerBox.width
                height: root.pickerBox.height
                anchors.centerIn: parent
                scale: Math.min(parent.width / Math.max(1, width), parent.height / Math.max(1, height))
                active: root.primary && (OverviewService.appsShown || OverviewService.appsProgress > 0 || root.appGridWarm)

                sourceComponent: AppGrid {
                    screen: root.screen
                    dragOverlay: root.dragOverlayItem
                }
            }
        }

        // Suche und Arbeitsflächen-Leiste gleiten von oben herein, aber nicht über die Top Bar: beschnitten am Streifen der Leiste.
        // Innen gelten Fensterkoordinaten minus workTop.
        Item {
            id: topClip
            y: root.workTop
            width: root.screenWidth
            height: root.screenHeight - root.workTop
            clip: true

        // Suche: fällt von oben herein [overviewControls.js:831-841]
        OverviewSlot {
            id: searchSlot
            visible: root.primary
            x: 0
            y: -(1 - root.progress) * (root.workTop + height)
            width: parent.width
            opacity: root.progress

            SearchBar {
                id: searchBar
                anchors.left: parent.left
                anchors.right: parent.right
                onAccepted: searchResults.activateSelected()
                onMoveSelection: (dx, dy) => searchResults.moveSelection(dx, dy)
                onEscapePressed: OverviewService.dismiss()
            }
        }

        // Arbeitsflächen-Leiste: gleitet von oben ein und bleibt bei aktiver Suche sichtbar (Overlay darüber)
        OverviewSlot {
            id: thumbnailsSlot
            visible: root.primary
            x: 0
            y: root.thumbnailsY - root.workTop - (1 - root.progress) * (root.thumbnailsY + height)
            width: parent.width
            opacity: root.progress
            // Nicht an der Deckkraft (= Fortschritt): der Wechsel von `enabled` bei 0.5 lief mitten in der Öffnungs-
            // animation durch die ganze Leiste
            enabled: OverviewService.searchProgress < 0.5

            // Immer geladen (Pre-Warm); die Aufnahmen laufen nur bei sichtbarer Übersicht.
            Loader {
                anchors.fill: parent
                active: root.primary

                sourceComponent: WorkspaceThumbnails {
                    screen: root.screen
                    workHeight: root.workHeight
                    wsModel: screenWorkspaces
                    captures: captureRegistry
                }
            }
        }

        }

        // Dash: steigt von unten auf [overviewControls.js:843-853]
        OverviewSlot {
            id: dashSlot
            visible: root.primary
            x: 0
            y: root.screenHeight - root.dashHeight + (1 - root.progress) * root.dashHeight
            width: root.screenWidth
            height: root.dashHeight
            opacity: root.progress

            Loader {
                anchors.fill: parent
                active: root.primary

                sourceComponent: Dash {
                    dragOverlay: root.dragOverlayItem
                    maxWidth: root.screenWidth
                    maxHeight: Math.round(root.workHeight * Theme.overviewDashMaxHeightRatio)
                }
            }
        }

        // Suchergebnisse als Overlay [GNOME Shell Design Dreams, „Search as Overlay“]: statt die Ansicht hart zu ersetzen,
        // wächst ein Panel aus dem Suchfeld über der Übersicht. Klick außerhalb des Panels beendet die Suche.
        Item {
            id: searchOverlay
            visible: root.primary && (OverviewService.searchProgress > 0 || panelSpringProgress > 0)
            anchors.fill: parent
            z: 20

            // Minimal: das Panel blendet ohne Feder/Bounce und ohne Aufwachsen ein
            property real panelSpringProgress: OverviewService.searchActive ? 1 : 0
            Behavior on panelSpringProgress {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: OverviewService.searchActive ? Theme.motionMedium : Theme.motionFast
                    easing.type: Theme.easeOut
                }
            }

            // Abdunkeln und Klick ins Leere (beendet nur die Suche, nicht die Übersicht)
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: root.workTop
                color: "black"
                opacity: Theme.searchOverlayScrim * OverviewService.searchProgress

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: SearchService.reset()
                }
            }

            // Eigene Layer-Fläche, damit Hyprland den Hintergrund hinter dem Panel verwischt (siehe OverlayLayer)
            OverlayLayer {
                screen: root.screen
                layerNamespace: "niselle-search"
                visible: searchOverlay.visible
                maskRect: Qt.rect(searchPanel.x - 16, searchPanel.y - 16, searchPanel.width + 32, searchPanel.height + 32)

                ShadowRect {
                    id: searchPanel

                    readonly property real maxHeight: Math.max(0, root.workBottom - y)

                    x: Math.round((root.screenWidth - width) / 2)
                    y: root.workTop + root.searchHeight + (1 - searchOverlay.panelSpringProgress) * Theme.searchOverlayStartOffset
                    width: Math.min(Theme.searchOverlayWidth, root.screenWidth - 2 * Theme.searchOverlayPadding)
                    // Mindesthöhe nur für den Platzhalter „Keine Ergebnisse“; Treffer bestimmen die Höhe selbst (sonst bleibt unter einem Rechner-Ergebnis leere Fläche)
                    height: Math.min(maxHeight, searchResults.total > 0 ? searchResults.wantedHeight : Theme.searchOverlayMinHeight)
                    color: Theme.glass(Theme.systemOverlayBg)
                    radius: Theme.searchOverlayRadius
                    opacity: searchOverlay.panelSpringProgress

                    Behavior on height {
                        enabled: !Theme.gameMode && OverviewService.searchProgress >= 1
                        NumberAnimation {
                            duration: Theme.durationButton
                            easing.type: Theme.easeEmphasized
                        }
                    }

                    // Klicks im Panel nicht an das Abdunkeln darunter weiterreichen
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                    }

                    SearchResults {
                        id: searchResults
                        anchors.fill: parent
                        anchors.margins: Theme.searchOverlayPadding
                    }
                }
            }
        }

        // Geöffneter App-Ordner: eigene Layer-Fläche über der ganzen Übersicht (nur primärer Monitor), damit Hyprland den Hintergrund verwischt
        OverlayLayer {
            screen: root.screen
            layerNamespace: "niselle-folder"
            visible: folderDialog.primary && (folderDialog.fade > 0 || folderDialog.open)
            keyboardFocus: folderDialog.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            AppFolderDialog {
                id: folderDialog
                windowWidth: root.screenWidth
                windowHeight: root.screenHeight
                primary: root.primary
                z: 200
            }
        }

        // Gezogene Fensterbilder liegen über allem
        Item {
            id: dragOverlay
            anchors.fill: parent
            z: 100
        }

        // Kachel eines Fensters, das von einem anderen Monitor hierher gezogen wird
        Rectangle {
            readonly property bool foreign: OverviewService.windowDragActive && OverviewService.windowDragScreen !== root.screen.name
            parent: dragOverlay
            visible: foreign
            width: OverviewService.windowDragSize.width
            height: OverviewService.windowDragSize.height
            x: OverviewService.windowDragPoint.x - root.screen.x - width / 2
            y: OverviewService.windowDragPoint.y - root.screen.y - height / 2
            radius: Theme.radiusThumbnail
            color: Theme.thumbnailBg
            opacity: Theme.windowDraggingOpacity * 2.5

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 6

                // Erst laden, wenn ein Symbol da ist: ein leerer Name lässt den Bildlader abstürzen
                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: OverviewService.windowDragActive && OverviewService.windowDragIcon !== ""
                    sourceComponent: Icon {
                        name: OverviewService.windowDragIcon
                        symbolic: false
                        size: Math.min(OverviewService.windowDragSize.width, OverviewService.windowDragSize.height) * 0.4
                    }
                }
                Text {
                    width: parent.width - 16
                    x: 8
                    text: OverviewService.windowDragTitle
                    color: Theme.systemFg
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
            }
        }

        // Mausrad wechselt die Arbeitsfläche, ohne Umlauf [workspacesView.js: _onScrollEvent]
        WheelHandler {
            property real accumulated: 0
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (!OverviewService.shown || OverviewService.searchActive) {
                    accumulated = 0;
                    return;
                }
                accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                const step = Theme.overviewWheelStep;
                if (Math.abs(accumulated) < step)
                    return;
                WorkspaceService.switchRelative(accumulated < 0 ? 1 : -1, root.screen);
                accumulated = 0;
            }
        }

        // Beim Öffnen bekommt das Suchfeld den Fokus; Tippen startet sofort die Suche [searchController.js]
        Connections {
            target: OverviewService
            function onShownChanged() {
                if (OverviewService.shown && root.primary)
                    searchBar.forceFocus();
            }
            // Sobald das App-Grid einmal geöffnet wurde, bleibt es geladen (Pre-Warm)
            function onAppsShownChanged() {
                if (OverviewService.appsShown)
                    root.appGridWarm = true;
            }
        }
    }
}
