import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

Item {
    id: root

    required property var screen


    readonly property var layout: AppGridService.layout
    readonly property var byId: AppGridService.model.byId

    property var mode: Theme.appGridModes[0]
    function updateMode() {
        const W = Math.max(1, width);
        const H = Math.max(1, height);
        const gutter = Math.max(W * Theme.appGridIndicatorGutterRatio, Theme.pageArrowSize);
        const ratio = (W - 2 * (Theme.appGridPagePaddingH + gutter)) / Math.max(1, H - 2 * Theme.appGridPagePaddingV);
        let best = Theme.appGridModes[0];
        let bestDiff = Infinity;
        for (const m of Theme.appGridModes) {
            const d = Math.abs(ratio - m.columns / m.rows);
            if (d < bestDiff) {
                bestDiff = d;
                best = m;
            }
        }
        root.mode = best;
    }
    onWidthChanged: root.updateMode()
    onHeightChanged: root.updateMode()
    readonly property int columns: mode.columns
    readonly property int rowsCount: mode.rows
    readonly property int itemsPerPage: columns * rowsCount

    Component.onCompleted: {
        root.updateMode();
        root.syncRevealOrigin();
    }

    Text {
        id: probe
        visible: false
        text: "Ag"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }
    readonly property real lineHeight: probe.implicitHeight

    readonly property var geometry: {
        const W = Math.max(1, width);
        const H = Math.max(1, height);
        const cols = columns;
        const rows = rowsCount;
        const gutter = Math.max(W * Theme.appGridIndicatorGutterRatio, Theme.pageArrowSize);
        const padL = Theme.appGridPagePaddingH + gutter;
        const padR = Theme.appGridPagePaddingH + gutter;
        const padT = Theme.appGridPagePaddingV;
        const padB = Theme.appGridPagePaddingV;
        const colSp = Theme.appGridColumnSpacing;
        const rowSp = Theme.appGridRowSpacing;
        const itemFor = size => size + 2 * Theme.overviewTilePadding + Theme.overviewTileSpacing + lineHeight;

        let iconSize = Theme.appGridIconSizes[Theme.appGridIconSizes.length - 1];
        let cell = itemFor(iconSize);
        for (const size of Theme.appGridIconSizes) {
            const item = itemFor(size);
            const emptyH = W - item * cols - colSp * (cols - 1) - padL - padR;
            const emptyV = H - item * rows - rowSp * (rows - 1) - padT - padB;
            if (emptyH >= 0 && emptyV > 0) {
                iconSize = size;
                cell = item;
                break;
            }
        }

        const emptyH = W - cell * cols - colSp * (cols - 1) - padL - padR;
        const emptyV = H - cell * rows - rowSp * (rows - 1) - padT - padB;
        let hSpacing = colSp + emptyH / (cols - 1);
        let left = padL;
        if (hSpacing > Theme.appGridMaxColumnSpacing) {
            const extra = (Theme.appGridMaxColumnSpacing - colSp) * (cols - 1);
            hSpacing = Theme.appGridMaxColumnSpacing;
            left += Math.max((emptyH - extra) / 2, 0);
        }
        let vSpacing = rowSp + emptyV / (rows - 1);
        let top = padT;
        if (vSpacing > Theme.appGridMaxRowSpacing) {
            const extra = (Theme.appGridMaxRowSpacing - rowSp) * (rows - 1);
            vSpacing = Theme.appGridMaxRowSpacing;
            top += Math.max((emptyV - extra) / 2, 0);
        }
        return {
            "iconSize": iconSize,
            "cell": cell,
            "hSpacing": hSpacing,
            "vSpacing": vSpacing,
            "left": left,
            "top": top
        };
    }

    readonly property var pages: {
        const perPage = itemsPerPage;
        const map = byId;
        const placed = {};
        const out = [];
        let carry = [];
        for (const page of layout.pages) {
            const ids = page.filter(id => {
                if (!map[id] || placed[id])
                    return false;
                placed[id] = true;
                return true;
            });
            const list = carry.concat(ids);
            if (list.length > 0)
                out.push(list.slice(0, perPage));
            carry = list.slice(perPage);
        }
        while (carry.length > 0) {
            out.push(carry.slice(0, perPage));
            carry = carry.slice(perPage);
        }
        let current = out.length > 0 ? out[out.length - 1] : null;
        for (const id of layout.unplaced) {
            if (!current || current.length >= perPage) {
                current = [];
                out.push(current);
            }
            current.push(id);
        }
        if (out.length === 0)
            out.push([]);
        return out;
    }
    readonly property int nPages: pages.length

    readonly property var pageLayout: {
        const g = root.geometry;
        const cols = root.columns;
        const o = root.revealOrigin;
        const half = g.cell / 2;
        const entries = root.pages.map(page => page.map((id, i) => {
                    const x = g.left + (i % cols) * (g.cell + g.hSpacing);
                    const y = g.top + Math.floor(i / cols) * (g.cell + g.vSpacing);
                    return {
                        "id": id,
                        "x": x,
                        "y": y,
                        "dist": Math.hypot(x + half - o.x, y + half - o.y)
                    };
                }));
        let maxDist = 1;
        for (const page of entries)
            for (const e of page)
                maxDist = Math.max(maxDist, e.dist);
        for (const page of entries)
            for (const e of page)
                e.delay = e.dist / maxDist;
        return entries;
    }

    property point revealOrigin: Qt.point(0, 0)
    function syncRevealOrigin() {
        const p = OverviewService.appsOrigin;
        root.revealOrigin = (p.x === 0 && p.y === 0) ? Qt.point(root.width / 2, root.height) : root.mapFromItem(null, p.x, p.y);
    }
    Connections {
        target: OverviewService
        function onAppsOriginChanged() {
            if (OverviewService.shown && OverviewService.appsShown)
                root.syncRevealOrigin();
        }
        function onAppsShownChanged() {
            if (OverviewService.appsShown)
                root.syncRevealOrigin();
        }
    }


    property real currentPage: 0
    Behavior on currentPage {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionMedium
            easing.type: Theme.easeEmphasized
        }
    }
    readonly property int nearestPage: Math.round(currentPage)

    property Item dragOverlay: null
    readonly property Item dragLayer: dragOverlay ? dragOverlay : localDragLayer

    Item {
        id: localDragLayer
        anchors.fill: parent
        z: 100
    }

    AppMenu {
        id: menu
        arrowSide: Qt.LeftEdge
    }

    function goToPage(page) {
        root.currentPage = Math.max(0, Math.min(page, root.nPages - 1));
    }
    function movePage(delta) {
        root.goToPage(root.nearestPage + delta);
    }

    onPagesChanged: root.currentPage = Math.max(0, Math.min(root.currentPage, root.nPages - 1))

    MouseArea {
        anchors.fill: parent
        enabled: OverviewService.appsShown && !root.dragging
        acceptedButtons: Qt.LeftButton
    }

    Item {
        id: viewport
        width: root.width
        height: root.height
        clip: true

        Item {
            id: strip
            width: root.width * root.nPages
            height: root.height
            x: -root.currentPage * root.width

            Repeater {
                model: root.pageLayout

                Item {
                    id: pageItem
                    required property var modelData
                    required property int index

                    x: index * root.width
                    width: root.width
                    height: root.height

                    DropArea {
                        anchors.fill: parent
                        keys: ["niselle-app"]
                        onDropped: dropEvent => root.dropOnEmpty(pageItem.index, dropEvent.source, dropEvent.x, dropEvent.y)
                    }

                    Repeater {
                        model: pageItem.modelData

                        AppGridItem {
                            required property var modelData

                            controller: root
                            item: root.byId[modelData.id]
                            pageIndex: pageItem.index
                            position: index
                            iconSize: root.geometry.iconSize
                            cellSize: root.geometry.cell
                            revealProgress: OverviewService.appsProgress
                            revealDelay: modelData.delay
                            revealOrigin: root.revealOrigin
                            x: modelData.x
                            y: modelData.y
                        }
                    }
                }
            }
        }
    }

    PageIndicators {
        id: indicators
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        nPages: root.nPages
        currentPosition: root.currentPage
        onPageActivated: page => root.goToPage(page)
    }

    IconButton {
        icon: Quickshell.shellPath("assets/icons/carousel-arrow-previous-symbolic.svg")
        flat: true
        bg: Theme.systemBase
        fg: Theme.systemFg
        visible: root.nearestPage > 0
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.movePage(-1)
    }
    IconButton {
        icon: Quickshell.shellPath("assets/icons/carousel-arrow-next-symbolic.svg")
        flat: true
        bg: Theme.systemBase
        fg: Theme.systemFg
        visible: root.nearestPage < root.nPages - 1
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.movePage(1)
    }

    WheelHandler {
        id: wheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: OverviewService.appsShown && !root.dragging

        onWheel: event => {
            if (scrollTimer.running)
                return;
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (delta === 0)
                return;
            root.movePage(delta < 0 ? 1 : -1);
            scrollTimer.restart();
        }
    }
    Timer {
        id: scrollTimer
        interval: Theme.appGridScrollTimeout
    }


    property bool dragging: false
    function dragStarted() {
        root.dragging = true;
    }
    function dragEnded() {
        root.dragging = false;
        edgeTimer.stop();
        root._edgeDir = 0;
    }

    property int _edgeDir: 0
    function dragMoved(x, y) {
        const p = root.mapFromItem(root.dragLayer, x, y);
        const gutter = Math.max(root.width * Theme.appGridIndicatorGutterRatio, Theme.pageArrowSize);
        let dir = p.x < gutter ? -1 : (p.x > root.width - gutter ? 1 : 0);
        if (root.nearestPage + dir < 0 || root.nearestPage + dir >= root.nPages)
            dir = 0;
        if (dir === root._edgeDir)
            return;
        root._edgeDir = dir;
        if (dir === 0) {
            edgeTimer.stop();
        } else {
            edgeTimer.interval = Theme.appGridDragPageSwitchInitial;
            edgeTimer.restart();
        }
    }
    Timer {
        id: edgeTimer
        onTriggered: {
            root.movePage(root._edgeDir);
            const next = root.nearestPage + root._edgeDir;
            if (next < 0 || next >= root.nPages) {
                root._edgeDir = 0;
                return;
            }
            edgeTimer.interval = Theme.appGridDragPageSwitchRepeat;
            edgeTimer.restart();
        }
    }

    function openFolder(id, origin) {
        OverviewService.openFolder(id, origin);
    }

    function _pagesCopy() {
        return root.pages.map(p => p.slice());
    }

    function _removeFromPages(pages, id) {
        for (const p of pages) {
            const i = p.indexOf(id);
            if (i >= 0)
                p.splice(i, 1);
        }
    }

    function dropOnItem(target, source, x) {
        if (!source || !source.gridId || source.gridId === target.item.id)
            return;
        const srcId = source.gridId;
        const dstId = target.item.id;
        const onEdge = x < Theme.appGridDividerLeeway || x > target.width - Theme.appGridDividerLeeway;
        if (!onEdge && source.gridKind === "app") {
            if (target.isFolder) {
                AppGridService.addAppToFolder(dstId, srcId);
                return;
            }
            if (target.item.kind === "app") {
                root._createFolder(srcId, dstId);
                return;
            }
        }
        root._moveItem(srcId, target.pageIndex, x < target.width / 2 ? target.position : target.position + 1);
    }

    function slotAt(pageIndex, px, py) {
        const g = root.geometry;
        const pitchX = g.cell + g.hSpacing;
        const pitchY = g.cell + g.vSpacing;
        const col = Math.max(0, Math.min(root.columns - 1, Math.floor((px - g.left + g.hSpacing / 2) / pitchX)));
        const row = Math.max(0, Math.min(root.rowsCount - 1, Math.floor((py - g.top + g.vSpacing / 2) / pitchY)));
        const inRight = (px - g.left - col * pitchX) > g.cell / 2;
        const count = root.pages[pageIndex] ? root.pages[pageIndex].length : 0;
        return Math.min(count, row * root.columns + col + (inRight ? 1 : 0));
    }

    function dropOnEmpty(pageIndex, source, x, y) {
        if (!source || !source.gridId)
            return;
        root._moveItem(source.gridId, pageIndex, root.slotAt(pageIndex, x, y));
    }

    function _moveItem(id, pageIndex, pos) {
        const pages = root._pagesCopy();
        const arr = pages[pageIndex] ?? pages[pages.length - 1];
        const from = arr.indexOf(id);
        const at = from >= 0 && from < pos ? pos - 1 : pos;
        root._removeFromPages(pages, id);
        arr.splice(Math.max(0, Math.min(at, arr.length)), 0, id);
        AppGridService.savePages(pages);
    }

    function placeDroppedApp(appId, windowX, windowY) {
        if (!root.byId[appId])
            return;
        const local = root.mapFromItem(null, windowX, windowY);
        const page = root.nearestPage;
        const px = local.x + root.currentPage * root.width - page * root.width;
        root._moveItem(appId, page, root.slotAt(page, px, local.y));
    }

    Connections {
        target: OverviewService

        function onAppDroppedInGrid(appId, x, y) {
            root.placeDroppedApp(appId, x, y);
        }
    }

    function _createFolder(srcId, dstId) {
        const pages = root._pagesCopy();
        const folderId = AppGridService.createFolder(dstId, srcId, null);
        for (const p of pages) {
            const i = p.indexOf(dstId);
            if (i >= 0)
                p[i] = folderId;
        }
        root._removeFromPages(pages, srcId);
        AppGridService.savePages(pages);
    }
}
