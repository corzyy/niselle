import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

// Geöffneter App-Ordner (.app-folder-dialog) [appDisplay.js: AppFolderDialog, _app-grid.scss:58-109].
// 720×720 große Fläche, Radius 64, auf dem System-Hintergrund; oben der Ordnername mit Stift-Knopf, darunter
// ein 3×3-Raster der Apps mit Seitenpunkten. Öffnen/Schließen 200 ms (Maßstab 0.9 → 1, Deckkraft), der
// Hintergrund dunkelt ab. Klick ins Leere und Esc schließen; Apps lassen sich aus dem Ordner herausziehen:
// auf dem Hintergrund losgelassen schließt der Ordner und die App kehrt an die Ablegestelle im App-Grid zurück,
// im Raster lassen sie sich umsortieren.
//
// Liegt als Overlay über der ganzen Übersicht (`windowWidth`/`windowHeight`), gesteuert über
// OverviewService.openFolderId. Der Dialog beginnt `panelHeight` unter der Fenstermitte [appDisplay.js: container padding-top].
Item {
    id: root

    required property real windowWidth
    required property real windowHeight
    // Nur der primäre Monitor zeigt den Ordner-Dialog
    property bool primary: true

    // Füllt das Fenster: der Hintergrund (Abdunklung, Klick schließt, Ablegen zum Herausziehen) liegt
    // darüber; ohne feste Größe wäre er 0×0 und Ziehen aus dem Ordner unmöglich.
    width: windowWidth
    height: windowHeight

    // Der Dialog liegt in einer eigenen Layer-Fläche mit Tastaturfokus: Esc schließt (zuerst den Ordner)
    focus: open
    Keys.onEscapePressed: OverviewService.dismiss()

    readonly property string folderId: OverviewService.openFolderId
    readonly property bool open: folderId !== "" && primary
    readonly property var folderItem: folderId !== "" ? AppGridService.model.byId[folderId] ?? null : null
    readonly property int appCount: folderItem ? folderItem.appIds.length : 0

    visible: primary && fade > 0
    property real fade: open ? 1 : 0
    Behavior on fade {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Theme.easeEmphasized
        }
    }

    // Aufwachsen aus der Ordner-Kachel: eigener Verlauf mit leichtem Überschwingen beim Öffnen, schnelles Einziehen beim Schließen
    property real grow: open ? 1 : 0
    Behavior on grow {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: root.open ? 460 : 220
            easing.type: root.open ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.9
        }
    }

    // ───────── Controller-Schnittstelle für AppGridItem ─────────

    property bool dragging: false
    function dragStarted() {
        root.dragging = true;
    }
    function dragEnded() {
        root.dragging = false;
    }
    readonly property alias dragLayer: dragLayer
    function openFolder(id) {
        OverviewService.openFolder(id);
    }

    // Einträge des Ordners als Rastereinträge
    readonly property var items: root.folderItem ? root.folderItem.appIds.map((id, i) => ({
                "id": id,
                "kind": "app",
                "name": root.folderItem.apps[i].name,
                "entry": root.folderItem.apps[i],
                "apps": []
            })) : []

    // ───────── Raster-Aufteilung (3 Spalten × 3 Zeilen) [FolderGrid]

    readonly property int columns: Theme.appFolderGridColumns
    readonly property int rowsCount: Theme.appFolderGridRows
    readonly property int perPage: columns * rowsCount
    readonly property var pages: {
        const out = [];
        for (let i = 0; i < Math.max(1, Math.ceil(items.length / perPage)); i++)
            out.push(items.slice(i * perPage, (i + 1) * perPage));
        return out;
    }
    property real currentPage: 0
    readonly property int nearestPage: Math.round(currentPage)

    Text {
        id: probe
        visible: false
        text: "Ag"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }
    Text {
        id: titleProbe
        visible: false
        text: "Ag"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeTitle1
        font.weight: Theme.fontWeightExtraBold
    }
    readonly property real lineHeight: probe.implicitHeight
    readonly property real nameRowHeight: titleProbe.implicitHeight + Theme.appFolderNamePaddingV
    readonly property real indicatorsHeight: Theme.pageIndicatorPaddingTop + Theme.pageIndicatorSize + Theme.appFolderIndicatorsMargin

    readonly property real gridWidth: Theme.appFolderSize - 2 * Theme.appGridPagePaddingH
    readonly property real gridHeight: Theme.appFolderSize - nameRowHeight - indicatorsHeight - Theme.appGridPagePaddingV

    readonly property var geometry: {
        const cols = columns;
        const rows = rowsCount;
        const colSp = Theme.appGridColumnSpacing;
        const rowSp = Theme.appGridRowSpacing;
        const itemFor = size => size + 2 * Theme.overviewTilePadding + Theme.overviewTileSpacing + lineHeight;
        let iconSize = Theme.appGridIconSizes[Theme.appGridIconSizes.length - 1];
        let cell = itemFor(iconSize);
        for (const size of Theme.appGridIconSizes) {
            const item = itemFor(size);
            if (item * cols + colSp * (cols - 1) <= gridWidth && item * rows + rowSp * (rows - 1) <= gridHeight) {
                iconSize = size;
                cell = item;
                break;
            }
        }
        const usedW = cell * cols + colSp * (cols - 1);
        const usedH = cell * rows + rowSp * (rows - 1);
        return {
            "iconSize": iconSize,
            "cell": cell,
            "hSpacing": colSp,
            "vSpacing": rowSp,
            "left": (gridWidth - usedW) / 2,
            "top": (gridHeight - usedH) / 2
        };
    }

    // Ordner verschwindet (leer, gelöscht): Dialog schließen
    onFolderItemChanged: {
        if (root.folderId !== "" && !root.folderItem)
            OverviewService.closeFolder();
    }

    // Geöffneten Ordner initialisieren
    onFolderIdChanged: {
        root.currentPage = 0;
        nameEntry.visible = false;
        nameLabel.visible = true;
    }

    // ───────── Hintergrund (Abdunklung), Klick schließt ─────────

    Rectangle {
        anchors.fill: parent
        color: Theme.glass(Theme.appFolderShade)
        opacity: root.fade

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: OverviewService.closeFolder()
        }

        // App aus dem Ordner ziehen und auf dem Hintergrund ablegen: der Ordner schließt und die App
        // landet an der Ablegestelle im App-Grid [appDisplay.js: AppFolderDialog.acceptDrop]
        DropArea {
            anchors.fill: parent
            keys: ["niselle-app"]
            onDropped: dropEvent => {
                const src = dropEvent.source;
                if (!src || !src.gridId || !root.folderItem || root.folderItem.appIds.indexOf(src.gridId) < 0)
                    return;
                const appId = src.gridId;
                AppGridService.removeAppFromFolder(root.folderId, appId);
                OverviewService.closeFolder();
                OverviewService.appDroppedInGrid(appId, dropEvent.x, dropEvent.y);
            }
        }
    }

    // ───────── Dialogfläche ─────────

    Rectangle {
        id: panel
        width: Theme.appFolderSize
        height: Theme.appFolderSize
        radius: Theme.radiusAppFolder
        color: Theme.glass(Theme.systemOverlayBg)
        border.width: Theme.appFolderBorderWidth
        border.color: Theme.systemBorders
        x: Math.round((root.windowWidth - width) / 2)
        y: Math.round((root.windowHeight + Theme.panelHeight - height) / 2)
        opacity: Math.min(1, root.fade * 2.5)
        transform: Scale {
            // Ursprung: Mitte der Kachel im Koordinatensystem der Fläche
            origin.x: OverviewService.folderOrigin.x < 0 ? panel.width / 2 : OverviewService.folderOrigin.x - panel.x
            origin.y: OverviewService.folderOrigin.y < 0 ? panel.height / 2 : OverviewService.folderOrigin.y - panel.y
            xScale: 0.12 + 0.88 * root.grow
            yScale: xScale
        }

        // Klicks in der Fläche nicht durchreichen
        MouseArea {
            anchors.fill: parent
        }

        // ───────── Ordnername mit Stift-Knopf ─────────

        Item {
            id: nameRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.nameRowHeight

            // Anklickbarer Name
            Text {
                id: nameLabel
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -Theme.iconButtonPadding
                text: root.folderItem ? root.folderItem.name : ""
                color: Theme.systemFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeTitle1
                font.weight: Theme.fontWeightExtraBold

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.startRename()
                }
            }

            Entry {
                id: nameEntry
                visible: false
                anchors.centerIn: nameLabel
                width: Theme.appFolderNameEntryWidth
                text: root.folderItem ? root.folderItem.name : ""
                onAccepted: root.commitRename()

                function start() {
                    text = root.folderItem ? root.folderItem.name : "";
                    visible = true;
                    forceFocus();
                }
            }

            IconButton {
                id: editButton
                icon: "document-edit-symbolic"
                flat: true
                bg: Theme.systemOverlayBg
                fg: Theme.systemFg
                anchors.left: nameLabel.right
                anchors.leftMargin: Theme.basePadding
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.startRename()
            }
        }

        function startRename() {
            nameLabel.visible = false;
            nameEntry.start();
        }
        function commitRename() {
            if (root.folderId !== "")
                AppGridService.renameFolder(root.folderId, nameEntry.text);
            nameEntry.visible = false;
            nameLabel.visible = true;
        }

        // ───────── Raster ─────────

        Item {
            id: gridArea
            anchors.left: parent.left
            anchors.top: nameRow.bottom
            anchors.leftMargin: Theme.appGridPagePaddingH
            anchors.topMargin: Theme.appGridPagePaddingV / 2
            width: root.gridWidth
            height: root.gridHeight
            clip: true

            Item {
                x: -root.currentPage * root.gridWidth
                width: root.gridWidth
                height: root.gridHeight

                Repeater {
                    model: root.pages

                    Item {
                        id: folderPage
                        required property var modelData
                        required property int index

                        x: index * root.gridWidth
                        width: root.gridWidth
                        height: root.gridHeight

                        DropArea {
                            anchors.fill: parent
                            keys: ["niselle-app"]
                            onDropped: dropEvent => {
                                const src = dropEvent.source;
                                if (!src || !src.gridId || !root.folderItem || src.gridKind !== "app")
                                    return;
                                if (root.folderItem.appIds.indexOf(src.gridId) < 0)
                                    AppGridService.addAppToFolder(root.folderId, src.gridId);
                                else
                                    root.moveTo(src.gridId, folderPage.index * root.perPage + root.slotAt(dropEvent.x, dropEvent.y));
                            }
                        }

                        Repeater {
                            model: folderPage.modelData

                            AppGridItem {
                                required property var modelData
                                required property int index

                                controller: root
                                nestFolders: false
                                item: modelData
                                pageIndex: folderPage.index
                                position: index
                                iconSize: root.geometry.iconSize
                                cellSize: root.geometry.cell
                                x: root.geometry.left + (index % root.columns) * (root.geometry.cell + root.geometry.hSpacing)
                                y: root.geometry.top + Math.floor(index / root.columns) * (root.geometry.cell + root.geometry.vSpacing)
                            }
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (delta === 0)
                        return;
                    root.currentPage = Math.max(0, Math.min(root.nearestPage + (delta < 0 ? 1 : -1), root.pages.length - 1));
                }
            }
        }

        PageIndicators {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.appFolderIndicatorsMargin
            nPages: root.pages.length
            currentPosition: root.currentPage
            onPageActivated: page => root.currentPage = page
        }
    }

    // Einfügeposition auf einer Seite für einen Punkt in Seitenkoordinaten
    function slotAt(px, py) {
        const g = root.geometry;
        const col = Math.max(0, Math.min(root.columns - 1, Math.floor((px - g.left + g.hSpacing / 2) / (g.cell + g.hSpacing))));
        const row = Math.max(0, Math.min(root.rowsCount - 1, Math.floor((py - g.top + g.vSpacing / 2) / (g.cell + g.vSpacing))));
        return row * root.columns + col;
    }

    // App an die Einfügeposition `pos` (Index in der gesamten Liste, vor dem Entfernen) setzen
    function moveTo(appId, pos) {
        const ids = root.folderItem.appIds.slice();
        const from = ids.indexOf(appId);
        if (from < 0)
            return;
        ids.splice(from, 1);
        ids.splice(Math.max(0, Math.min(from < pos ? pos - 1 : pos, ids.length)), 0, appId);
        AppGridService.setFolderApps(root.folderId, ids);
    }

    // Umsortieren innerhalb des Ordners (Position ist seitenweise, daher in die Gesamtliste umrechnen)
    function dropOnItem(target, source, x) {
        if (!source || !source.gridId || !root.folderItem || source.gridKind !== "app")
            return;
        if (root.folderItem.appIds.indexOf(source.gridId) < 0) {
            AppGridService.addAppToFolder(root.folderId, source.gridId);
            return;
        }
        if (source.gridId === target.item.id)
            return;
        root.moveTo(source.gridId, target.pageIndex * root.perPage + target.position + (x < target.width / 2 ? 0 : 1));
    }

    // Gezogene Icons über dem Dialog
    Item {
        id: dragLayer
        anchors.fill: parent
        z: 100
    }
}
