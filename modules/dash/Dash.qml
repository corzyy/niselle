import QtQuick
import qs
import qs.services
import qs.components

// Dash [dash.js, _dash.scss]: Pille mit angehefteten und laufenden Apps, Trennlinie dazwischen, „Apps anzeigen“ ganz rechts.
// Füllt den Dash-Slot der Übersicht; die Pille liegt oben im Slot, darunter bleibt der Randabstand (dashEdgeOffset).
//
// Reihenfolge: Favoriten, dann laufende Apps ohne Favorit; Apps ohne Desktop-Eintrag (kind "win") erscheinen als laufende Apps.
// Die Einträge liegen in `model` und werden bei Änderungen abgeglichen (applyModel), damit neue Einträge einwachsen und
// entfernte schrumpfen [dash.js: _redisplay, DashItemContainer.show/animateOutAndDestroy]; Animationen laufen nur bei sichtbarer,
// ruhender Übersicht.
//
// Ziehen [dash.js: handleDragOver/acceptDrop]: Einträge setzen beim Ziehen über die Leiste einen Platzhalter in den Favoritenbereich;
// Ablegen heftet an oder verschiebt. Quelle ist ein Objekt mit Schlüssel "niselle-app" und den Eigenschaften `entry`, `favorite`
// (so ziehen später auch App-Grid-Icons hinein).
Item {
    id: root

    // Platz, den die Übersicht dem Dash höchstens gibt (setMaxSize) [overviewControls.js:173-181]
    property real maxWidth: width
    property real maxHeight: 100000

    readonly property alias menu: menu
    readonly property bool anyMenuOpen: menu.open || showApps.menuOpen
    // Mit `dragOverlay` (Overview) liegen gezogene Icons über der ganzen Übersicht, damit sie beim Ziehen auf eine
    // Arbeitsflächen-Vorschau sichtbar bleiben; ohne Overlay (Dock) bleibt die Ebene im Dash.
    property Item dragOverlay: null
    readonly property Item dragLayer: dragOverlay ? dragOverlay : localDragLayer

    // ───────── Größen ─────────

    // Favoriten, dann laufende Apps; nFav = Zahl der Favoriten
    readonly property var appsInfo: {
        const list = [];
        const seen = {};
        for (const e of AppsService.favorites) {
            seen["app:" + e.id] = true;
            list.push({
                "key": "app:" + e.id,
                "kind": "app",
                "appId": e.id
            });
        }
        const nFav = list.length;
        for (const r of AppsService.runningApps) {
            const key = r.entry ? "app:" + r.entry.id : "win:" + r.appId.toLowerCase();
            if (seen[key])
                continue;
            seen[key] = true;
            list.push({
                "key": key,
                "kind": r.entry ? "app" : "win",
                "appId": r.entry ? r.entry.id : r.appId.toLowerCase()
            });
        }
        return {
            "list": list,
            "nFav": nFav
        };
    }

    // Größte Icongröße, die in Breite (alle Einträge samt „Apps anzeigen“) und Höhe passt [dash.js:573-628]
    readonly property int iconSize: {
        const n = root.appsInfo.list.length + 1;
        const tileExtra = 2 * Theme.tilePadding;
        const availW = root.maxWidth - 2 * Theme.dashOuterPadding - n * (2 * Theme.dashItemSpacing + tileExtra);
        const availH = root.maxHeight - 2 * Theme.dashPadding - (tileExtra + Theme.dashEdgeOffset);
        const maxIcon = Math.min(availW / n, availH);
        let size = Theme.dashIconSizes[0];
        for (const s of Theme.dashIconSizes) {
            if (s <= maxIcon && s <= SettingsService.dockIconSize)
                size = s;
        }
        return size;
    }
    // Die Icongröße wechselt über 200 ms [dash.js:660-666]
    property real iconSizeShown: iconSize
    readonly property real tileSize: iconSizeShown + 2 * Theme.tilePadding
    readonly property real cellWidth: tileSize + 2 * Theme.dashItemSpacing
    // Höhe eines Eintrags samt Klickfläche: Kachel, Hintergrund-Padding, Randabstand
    readonly property real columnHeight: tileSize + 2 * Theme.dashPadding + Theme.dashEdgeOffset

    implicitWidth: contentRow.width + 2 * Theme.dashOuterPadding + 2 * (Theme.dashPadding - Theme.dashItemSpacing)
    implicitHeight: columnHeight

    Behavior on iconSizeShown {
        enabled: (root.animate) && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Theme.easeEmphasized
        }
    }

    // ───────── Zustand ─────────

    property bool ready: false
    // Einblenden/Ausblenden von Einträgen nur bei offener, ruhender Übersicht [dash.js:794-798]
    readonly property bool animate: ready && OverviewService.shown && !OverviewService.animating

    // Platzhalter beim Ziehen: Index unter den Apps (-1: keiner)
    property int placeholderPos: -1
    property int dragCount: 0
    readonly property bool dragging: dragCount > 0
    // Beim Ablegen verschwindet der Platzhalter ohne Animation
    property bool instantPlaceholder: false
    property int nextUid: 1

    // Gewünschte Einträge in Reihenfolge, samt Platzhalter, Trennlinie und leerem Ablageziel
    readonly property var desired: {
        const info = root.appsInfo;
        const apps = info.list.slice();
        if (root.placeholderPos >= 0) {
            apps.splice(Math.min(root.placeholderPos, apps.length), 0, {
                "key": "placeholder",
                "kind": "placeholder",
                "appId": ""
            });
        }
        const out = [];
        if (root.dragging && info.list.length === 0) {
            out.push({
                "key": "empty",
                "kind": "empty",
                "appId": ""
            });
        }
        const nBefore = info.nFav + (root.placeholderPos >= 0 ? 1 : 0);
        const hasSeparator = info.nFav > 0 && info.nFav < info.list.length;
        for (let i = 0; i < apps.length; i++) {
            if (hasSeparator && i === nBefore) {
                out.push({
                    "key": "separator",
                    "kind": "separator",
                    "appId": ""
                });
            }
            out.push(apps[i]);
        }
        return out;
    }
    onDesiredChanged: applyModel()

    ListModel {
        id: model
    }

    function _liveIndex(key) {
        for (let i = 0; i < model.count; i++) {
            const m = model.get(i);
            if (!m.removing && m.itemKey === key)
                return i;
        }
        return -1;
    }

    // Modell dem Soll angleichen: neue Einträge einfügen, fehlende ausblenden, Reihenfolge herstellen.
    // Ausblendende Einträge bleiben stehen, bis ihre Animation endet (finishRemove).
    function applyModel() {
        const want = {};
        for (const d of root.desired)
            want[d.key] = true;
        for (let i = model.count - 1; i >= 0; i--) {
            const m = model.get(i);
            if (m.removing || want[m.itemKey])
                continue;
            const instant = m.kind === "separator" || (m.kind === "placeholder" && root.instantPlaceholder);
            if (root.animate && !instant)
                model.setProperty(i, "removing", true);
            else
                model.remove(i);
        }
        let p = 0;
        for (const d of root.desired) {
            while (p < model.count && model.get(p).removing)
                p++;
            const j = root._liveIndex(d.key);
            if (j < 0) {
                model.insert(p, {
                    "itemKey": d.key,
                    "kind": d.kind,
                    "appId": d.appId,
                    "uid": root.nextUid++,
                    "animateIn": root.animate && d.kind !== "separator",
                    "removing": false
                });
            } else if (j !== p) {
                model.move(j, p, 1);
            }
            p++;
        }
    }

    function finishRemove(uid) {
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).uid === uid) {
                model.remove(i);
                return;
            }
        }
    }

    Component.onCompleted: {
        applyModel();
        ready = true;
    }

    // ───────── Ziehen ─────────

    function dragStarted() {
        root.dragCount++;
    }
    function dragEnded() {
        root.dragCount = Math.max(0, root.dragCount - 1);
        if (root.dragCount === 0)
            root.clearPlaceholder();
    }
    function clearPlaceholder(instant) {
        root.instantPlaceholder = instant === true;
        root.placeholderPos = -1;
        root.instantPlaceholder = false;
    }

    function _favoriteIndex(entry) {
        const key = "app:" + entry.id;
        const list = root.appsInfo.list;
        for (let i = 0; i < root.appsInfo.nFav; i++) {
            if (list[i].key === key)
                return i;
        }
        return -1;
    }

    // Platzhalter nachführen [dash.js:861-940]; x in Koordinaten der Eintragsleiste
    function dragMotion(source, x) {
        if (!source || !source.entry)
            return;
        let width = itemsRow.width;
        let count = 0;
        for (let i = 0; i < itemsRepeater.count; i++) {
            const cell = itemsRepeater.itemAt(i);
            if (!cell)
                continue;
            if (cell.kind === "placeholder" || cell.kind === "separator")
                width -= cell.width;
            else
                count++;
        }
        let pos = 0;
        if (count > 0 && width > 0)
            pos = Math.floor(x * count / width);
        pos = Math.max(0, Math.min(pos, root.appsInfo.nFav));
        if (pos === root.placeholderPos)
            return;
        // Nicht direkt vor oder hinter sich selbst einfügen
        const own = root._favoriteIndex(source.entry);
        if (own !== -1 && (pos === own || pos === own + 1)) {
            root.clearPlaceholder();
            return;
        }
        root.placeholderPos = pos;
    }

    // Ablegen [dash.js:943-989]: ohne Platzhalter bleibt alles, wie es ist
    function acceptDrop(source) {
        if (!source || !source.entry || root.placeholderPos < 0)
            return;
        const own = root._favoriteIndex(source.entry);
        const pos = root.placeholderPos - (own !== -1 && own < root.placeholderPos ? 1 : 0);
        root.clearPlaceholder(true);
        if (source.favorite)
            AppsService.moveFavorite(source.entry, pos);
        else
            AppsService.addFavorite(source.entry, pos);
    }

    // ───────── Tooltip ─────────
    // Ein Tooltip für alle Einträge. Erscheint nach 300 ms, wechselt der Zeiger zum Nachbarn, sofort [dash.js:539-571]

    property Item labelItem: null
    property bool labelShowing: false

    function syncLabel(item) {
        if (item.wantsLabel) {
            if (!showTimer.running) {
                showTimer.item = item;
                showTimer.interval = root.labelShowing ? 0 : Theme.dashItemHoverTimeout;
                showTimer.start();
                resetTimer.stop();
            }
        } else {
            if (showTimer.running && showTimer.item === item)
                showTimer.stop();
            root.hideLabel(item);
            if (root.labelShowing && !showTimer.running)
                resetTimer.restart();
        }
    }

    function hideLabel(item) {
        if (root.labelItem === item)
            tooltip.shown = false;
    }

    function _showLabel(item) {
        if (!item || !item.wantsLabel)
            return;
        root.labelItem = item;
        root.labelShowing = true;
        tooltip.text = item.label;
        const center = item.mapToItem(root, item.width / 2, 0).x;
        tooltip.x = Math.max(0, Math.min(center - tooltip.width / 2, root.width - tooltip.width));
        tooltip.y = -tooltip.height - Theme.dashLabelOffsetY;
        tooltip.shown = true;
    }

    Timer {
        id: showTimer
        property Item item: null
        onTriggered: root._showLabel(item)
    }
    Timer {
        id: resetTimer
        interval: Theme.dashItemHoverTimeout
        onTriggered: root.labelShowing = false
    }

    // Übersicht schließt: Tooltip weg [dash.js:493-496]
    Connections {
        target: OverviewService
        function onShownChanged() {
            if (!OverviewService.shown) {
                showTimer.stop();
                tooltip.shown = false;
                root.labelShowing = false;
            }
        }
    }

    // ───────── Aufbau ─────────

    // Hintergrund hinter den Einträgen; fängt Klicks ab, damit die Übersicht nicht schließt
    Rectangle {
        readonly property real pad: Theme.dashPadding - Theme.dashItemSpacing

        x: contentRow.x - pad
        y: 0
        width: contentRow.width + 2 * pad
        height: root.tileSize + 2 * Theme.dashPadding
        radius: Theme.radiusDash
        color: Theme.dashBackground

        MouseArea {
            anchors.fill: parent
        }
    }

    Row {
        id: contentRow
        x: (root.width - width) / 2
        spacing: 0

        Row {
            id: itemsRow
            spacing: 0

            Repeater {
                id: itemsRepeater
                model: model

                delegate: Item {
                    id: cell

                    required property string itemKey
                    required property string kind
                    required property string appId
                    required property int uid
                    required property bool animateIn
                    required property bool removing

                    readonly property bool isApp: kind === "app" || kind === "win"
                    readonly property real natural: {
                        if (isApp)
                            return root.cellWidth;
                        if (kind === "separator")
                            return Theme.dashSeparatorWidth + 2 * Theme.dashSeparatorMargin;
                        if (kind === "placeholder")
                            return root.iconSizeShown;
                        return Theme.dashPlaceholderSize;
                    }

                    // 0 → 1 beim Einblenden, 1 → 0 beim Ausblenden [dash.js:154-185]
                    property bool entered: !animateIn
                    property real factor: entered && !removing ? 1 : 0

                    width: natural * factor
                    height: root.columnHeight

                    Behavior on factor {
                        enabled: !Theme.gameMode
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easeEmphasized
                        }
                    }

                    function _finish() {
                        if (cell.removing && cell.factor === 0)
                            Qt.callLater(root.finishRemove, cell.uid);
                    }
                    onFactorChanged: _finish()
                    onRemovingChanged: _finish()
                    Component.onCompleted: entered = true

                    Item {
                        width: cell.natural
                        height: parent.height
                        x: (cell.width - width) / 2
                        scale: cell.factor
                        opacity: cell.factor
                        transformOrigin: Item.Center

                        Loader {
                            anchors.fill: parent
                            sourceComponent: cell.isApp ? appItem : (cell.kind === "separator" ? separator : null)
                        }
                    }

                    Component {
                        id: appItem

                        DashItem {
                            dash: root
                            kind: cell.kind
                            appId: cell.appId
                            x: Theme.dashItemSpacing
                            width: root.tileSize
                            height: root.columnHeight
                        }
                    }

                    Component {
                        id: separator

                        // Dünne, durchgehende Linie, etwas kürzer als die Icons.
                        // Der Loader füllt die Zelle und würde ein Rectangle direkt darin aufziehen, daher der Item-Rahmen.
                        Item {
                            Rectangle {
                                x: Theme.dashSeparatorMargin
                                y: (root.columnHeight - Theme.dashEdgeOffset - height) / 2
                                width: Theme.dashSeparatorWidth
                                height: Math.round(root.tileSize * 0.75)
                                color: Theme.dashSeparator
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: root.cellWidth
            height: root.columnHeight

            ShowAppsButton {
                id: showApps
                dash: root
                x: Theme.dashItemSpacing
                width: root.tileSize
                height: root.columnHeight
            }
        }
    }

    // Ablegeziel: die Eintragsleiste
    DropArea {
        x: contentRow.x + itemsRow.x
        y: 0
        width: itemsRow.width
        height: root.columnHeight
        keys: ["niselle-app"]
        onEntered: drag => root.dragMotion(drag.source, drag.x)
        onPositionChanged: drag => root.dragMotion(drag.source, drag.x)
        onExited: root.clearPlaceholder()
        onDropped: drop => root.acceptDrop(drop.source)
    }

    TooltipLabel {
        id: tooltip

        property bool shown: false

        z: 10
        visible: opacity > 0
        opacity: shown ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: tooltip.shown ? Theme.durationDashLabelShow : Theme.durationDashLabelHide
                easing.type: Theme.easeOut
            }
        }
    }

    // Gezogene Icons liegen über allem
    Item {
        id: localDragLayer
        anchors.fill: parent
        z: 100
    }

    AppMenu {
        id: menu
    }

}
