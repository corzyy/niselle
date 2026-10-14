import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services

Item {
    id: root

    required property string groupKey
    property bool expanded: false
    property var now: new Date()

    readonly property var current: NotificationService.groups.find(g => g.key === groupKey) ?? null
    property var _last: null
    readonly property var groupData: current ?? _last
    readonly property string title: groupData ? (groupData.desktopEntry ? (DesktopEntries.heuristicLookup(groupData.desktopEntry)?.name ?? groupData.appName) : groupData.appName) : ""

    readonly property int visibleCount: {
        let c = 0;
        for (let i = 0; i < rows.count; i++)
            if (!rows.get(i).removing)
                c++;
        return c;
    }
    readonly property bool effectiveExpanded: expanded || visibleCount <= 1
    readonly property bool hasUrgent: current ? current.notifications.some(n => n.urgency === NotificationUrgency.Critical) : false

    property real expansion: expanded ? 1 : 0
    property bool _initialized: false

    signal expandToggleRequested
    signal activated

    implicitHeight: contentHeight
    height: contentHeight
    property real contentHeight: 0
    property real expandedHeight: 0

    Behavior on expansion {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.durationGroupExpand
            easing.type: Theme.easeOutQuad
        }
    }
    onExpansionChanged: relayout()
    onWidthChanged: relayout()

    ListModel {
        id: rows
    }

    onCurrentChanged: {
        if (current)
            _last = current;
        sync();
    }

    Component.onCompleted: {
        if (current)
            _last = current;
        sync();
        _initialized = true;
        relayout();
    }

    function rowIndexForPos(pos) {
        let count = 0;
        for (let i = 0; i < rows.count; i++) {
            if (rows.get(i).removing)
                continue;
            if (count === pos)
                return i;
            count++;
        }
        return rows.count;
    }

    function rowOf(id) {
        for (let i = 0; i < rows.count; i++)
            if (rows.get(i).nid === id)
                return i;
        return -1;
    }

    function sync() {
        const all = current ? current.notifications : [];
        const isCritical = n => n.urgency === NotificationUrgency.Critical;
        const list = all.filter(isCritical).concat(all.filter(n => !isCritical(n)));
        const ids = list.map(n => n.id);

        for (let i = 0; i < rows.count; i++) {
            if (!rows.get(i).removing && ids.indexOf(rows.get(i).nid) < 0)
                rows.setProperty(i, "removing", true);
        }
        list.forEach((n, pos) => {
            const idx = rowOf(n.id);
            const target = rowIndexForPos(pos);
            if (idx < 0) {
                rows.insert(target, {
                    "nid": n.id,
                    "removing": false
                });
            } else if (idx !== target) {
                rows.move(idx, idx < target ? target - 1 : target, 1);
            }
        });
        relayout();
    }

    function removeRow(id) {
        const i = rowOf(id);
        if (i >= 0)
            rows.remove(i);
        if (root.expanded && root.visibleCount === 1)
            root.expandToggleRequested();
        relayout();
    }

    function closeAll() {
        NotificationService.dismissGroup(root.groupKey);
    }

    function relayout() {
        const items = [];
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it)
                items.push(it);
        }
        const e = root.expansion;
        const w = root.width;
        const headerH = header.implicitHeight;

        let offset = Theme.groupStackHeightOffset;
        let collapsed = 0;
        let shown = 0;
        for (const it of items) {
            if (shown === 0) {
                collapsed = it.height;
            } else {
                collapsed += offset;
                offset /= Theme.groupStackHeightReduction;
            }
            if (++shown === Theme.groupMaxVisibleStacked)
                break;
        }
        let expandedH = headerH + Theme.groupExpandedBottomMargin;
        for (const it of items)
            expandedH += it.height;
        root.expandedHeight = expandedH;
        const total = collapsed + e * (expandedH - collapsed);
        root.contentHeight = total;

        header.y = 0;
        header.width = w;

        let x1 = 0;
        let x2 = w;
        let y1 = header.visible ? e * headerH : 0;
        let y2 = y1;
        let heightOffset = Theme.groupStackHeightOffset;
        items.forEach((it, i) => {
            it.z = items.length - i;
            if (i === 0) {
                y2 = y1 + it.height;
                it.x = x1;
                it.width = x2 - x1;
                it.y = y1;
                return;
            }
            const widthOffset = (1 - e) * Theme.groupStackWidthOffset;
            x1 += widthOffset;
            x2 -= widthOffset;
            y2 += heightOffset + e * (it.height - heightOffset);
            if (y2 > total)
                y2 = total;
            else
                heightOffset /= Theme.groupStackHeightReduction;
            it.x = x1;
            it.width = x2 - x1;
            it.y = y2 - it.height;
        });
        cover.z = items.length > 0 ? items.length - 0.5 : 0;
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.expandToggleRequested()
    }

    RowLayout {
        id: header

        visible: opacity > 0
        opacity: root.expansion
        z: -0.5
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.margins: Theme.groupHeaderPadding
            Layout.leftMargin: Theme.groupHeaderPadding + Theme.groupTitleMargin
            text: root.title
            elide: Text.ElideRight
            color: Theme.fgColor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeTitle2
            font.weight: Theme.fontWeightExtraBold
        }
        Item {
            Layout.margins: Theme.groupHeaderPadding
            implicitWidth: Theme.iconSize + 2 * (Theme.groupCollapsePadding + Theme.groupCollapseBorder)
            implicitHeight: implicitWidth

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: collapseMouse.pressed ? Theme.groupCollapseBg : (collapseMouse.containsMouse ? Theme.groupCollapseBgHover : Theme.groupCollapseBg)
            }
            Icon {
                anchors.centerIn: parent
                name: Quickshell.shellPath("assets/icons/group-collapse-symbolic.svg")
                size: Theme.iconSize
                color: Theme.fgColor
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: "transparent"
                border.width: Theme.focusRingWidth
                border.color: Theme.focusRing
                visible: parent.activeFocus
            }
            activeFocusOnTab: true
            Keys.onReturnPressed: root.expandToggleRequested()
            Keys.onSpacePressed: root.expandToggleRequested()
            MouseArea {
                id: collapseMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.expandToggleRequested()
            }
        }
    }

    MouseArea {
        id: cover
        anchors.fill: parent
        enabled: !root.effectiveExpanded
        onClicked: root.expandToggleRequested()
    }

    Repeater {
        id: repeater
        model: rows

        ScaleBin {
            id: bin

            required property int index
            required property int nid
            required property bool removing

            animateIn: root._initialized && rows.count > 1
            shown: !removing
            scalingEnabled: true
            onHeightChanged: root.relayout()
            Component.onCompleted: root.relayout()
            onHidden: root.removeRow(nid)

            Item {
                width: parent.width
                height: msg.implicitHeight + Theme.messageSpacing

                NotificationMessage {
                    id: msg

                    readonly property var found: NotificationService.notifications.find(n => n.id === bin.nid) ?? null

                    width: parent.width
                    height: implicitHeight
                    notification: found
                    now: root.now
                    stackLevel: root.effectiveExpanded ? 0 : Math.min(2, bin.index)
                    onFoundChanged: if (found)
                        snapshot()

                    onClicked: {
                        if (!root.effectiveExpanded) {
                            root.expandToggleRequested();
                        } else if (NotificationService.activateDefault(found)) {
                            root.activated();
                        }
                    }
                    onCloseRequested: {
                        if (!root.effectiveExpanded)
                            root.closeAll();
                        else
                            NotificationService.dismiss(found);
                    }
                    onExpandRequested: expand => {
                        msg.expanded = expand;
                        if (expand && !root.effectiveExpanded)
                            root.expandToggleRequested();
                    }

                    Connections {
                        target: root
                        function onExpandedChanged() {
                            if (!root.expanded)
                                msg.expanded = false;
                        }
                    }
                }
            }
        }

        onItemAdded: root.relayout()
        onItemRemoved: root.relayout()
    }
}
