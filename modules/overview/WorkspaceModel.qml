import QtQuick
import qs
import qs.services

Item {
    id: root

    required property var screen

    readonly property alias model: rows
    readonly property int retain: Theme.motionSlow + 80

    visible: false

    readonly property var list: {
        void WorkspaceService.revision;
        return WorkspaceService.workspacesFor(screen);
    }
    readonly property int count: list.length

    readonly property int pendingId: WorkspaceService.pendingFor(screen)
    readonly property int rawActiveIndex: {
        const real = list.findIndex(w => w.active);
        if (pendingId >= 0 && (real < 0 || list[real].id !== pendingId)) {
            const pending = list.findIndex(w => w.id === pendingId);
            if (pending >= 0)
                return pending;
        }
        return real;
    }
    property int activeIndex: 0
    onRawActiveIndexChanged: {
        if (rawActiveIndex >= 0)
            activeIndex = rawActiveIndex;
    }
    readonly property int activeId: list[activeIndex]?.id ?? -1

    property real position: activeIndex
    Behavior on position {
        enabled: OverviewService.shown && !Theme.gameMode
        NumberAnimation {
            duration: Theme.motionSlow
            easing.type: Theme.easeOut
        }
    }

    property var infoMap: ({})
    property var slotMap: ({})

    function infoFor(id) {
        return root.infoMap[id] ?? null;
    }
    function slotFor(id) {
        return root.slotMap[id] ?? 0;
    }

    ListModel {
        id: rows
    }

    Timer {
        id: purgeTimer
        interval: root.retain
        onTriggered: root._purge()
    }

    onListChanged: root._sync()
    Component.onCompleted: {
        root.activeIndex = Math.max(0, root.rawActiveIndex);
        root._sync();
    }

    function _rowOf(id) {
        for (let i = 0; i < rows.count; i++) {
            if (rows.get(i).wsId === id)
                return i;
        }
        return -1;
    }

    function _sync() {
        const list = root.list;
        const info = {};
        const slots = {};
        for (let i = 0; i < list.length; i++) {
            info[list[i].id] = list[i];
            slots[list[i].id] = i;
        }
        let infoChanged = false;
        const nextInfo = Object.assign({}, root.infoMap);
        for (const id in info) {
            const prev = nextInfo[id];
            if (!root._sameInfo(prev, info[id])) {
                nextInfo[id] = info[id];
                infoChanged = true;
            }
        }
        if (infoChanged)
            root.infoMap = nextInfo;
        let slotsChanged = false;
        for (const id in slots) {
            if (root.slotMap[id] !== slots[id])
                slotsChanged = true;
        }
        if (slotsChanged)
            root.slotMap = Object.assign({}, root.slotMap, slots);

        let anyGone = false;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            const present = info[r.wsId] !== undefined;
            if (!present && !r.gone) {
                rows.setProperty(i, "gone", true);
                rows.setProperty(i, "goneAt", Date.now());
            } else if (present && r.gone) {
                rows.setProperty(i, "gone", false);
            }
            if (!present)
                anyGone = true;
        }

        let cursor = 0;
        for (const w of list) {
            while (cursor < rows.count && rows.get(cursor).gone && rows.get(cursor).wsId !== w.id)
                cursor++;
            const at = root._rowOf(w.id);
            if (at < 0)
                rows.insert(cursor, {
                    "wsId": w.id,
                    "gone": false,
                    "goneAt": 0
                });
            else if (at > cursor)
                rows.move(at, cursor, 1);
            cursor++;
        }

        if (anyGone)
            purgeTimer.restart();
    }

    function _sameInfo(a, b) {
        if (!a || !b)
            return false;
        if (a.id !== b.id || a.index !== b.index || a.workspace !== b.workspace || a.active !== b.active || a.urgent !== b.urgent || a.empty !== b.empty || a.windows.length !== b.windows.length)
            return false;
        for (let i = 0; i < a.windows.length; i++) {
            if (a.windows[i] !== b.windows[i])
                return false;
        }
        return true;
    }

    function _purge() {
        const now = Date.now();
        let remaining = false;
        for (let i = rows.count - 1; i >= 0; i--) {
            const r = rows.get(i);
            if (!r.gone)
                continue;
            if (now - r.goneAt >= root.retain - 20) {
                const infoMap = Object.assign({}, root.infoMap);
                const slotMap = Object.assign({}, root.slotMap);
                delete infoMap[r.wsId];
                delete slotMap[r.wsId];
                rows.remove(i);
                root.infoMap = infoMap;
                root.slotMap = slotMap;
            } else {
                remaining = true;
            }
        }
        if (remaining)
            purgeTimer.restart();
    }
}
