import QtQuick
import QtQuick.Layouts
import qs

// Anordnungsvorschau der Anzeigen (gnome-control-center cc-display-arrangement): die Monitore werden maßstäblich
// angeordnet, mit Nummer in der Mitte, dicker Oberkante für die Primäranzeige und Akzentrahmen für die Auswahl.
// Ziehen verschiebt einen Monitor im Raster; Kanten rasten an den Nachbarn ein.
Item {
    id: root

    // [{ name, number, x, y, w, h, primary, selected }] – x/y/w/h in logischen Layout-Einheiten
    property var monitors: []
    property string selected: ""

    signal monitorSelected(string name)
    signal monitorMoved(string name, int x, int y)

    readonly property real marginMon: 0.66
    readonly property real dragThreshold: 25

    // Maßstab und Mittelpunkt des Layouts, damit alles in die Fläche passt
    readonly property var _box: {
        let x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity, maxW = 0, maxH = 0;
        for (const m of monitors) {
            x1 = Math.min(x1, m.x);
            y1 = Math.min(y1, m.y);
            x2 = Math.max(x2, m.x + m.w);
            y2 = Math.max(y2, m.y + m.h);
            maxW = Math.max(maxW, m.w);
            maxH = Math.max(maxH, m.h);
        }
        if (monitors.length === 0)
            return { "x1": 0, "y1": 0, "x2": 0, "y2": 0 };
        return { "x1": x1, "y1": y1, "x2": x2, "y2": y2, "maxW": maxW, "maxH": maxH };
    }
    readonly property real scale: {
        const b = _box;
        if (monitors.length === 0)
            return 1;
        const sw = (width) / (b.x2 - b.x1 + b.maxW * 2 * marginMon);
        const sh = (height) / (b.y2 - b.y1 + b.maxH * 2 * marginMon);
        return Math.max(0.0001, Math.min(sw, sh));
    }
    readonly property real _cx: (root._box.x1 + root._box.x2) / 2
    readonly property real _cy: (root._box.y1 + root._box.y2) / 2

    function px(m, key) {
        const v = (key === "x") ? m.x : m.y;
        const c = (key === "x") ? root._cx : root._cy;
        const size = (key === "x") ? root.width : root.height;
        return size / 2 + root.scale * (v - c);
    }

    implicitHeight: 200

    // Das Modell sind nur die Namen: beim Ziehen ändert sich jedes Mal Position und damit `monitors`. Mit einem
    // Modell aus Objekten würde der Repeater alle Delegates neu bauen und den Zug mitten in der Bewegung abbrechen;
    // eine unveränderte Namensliste lässt die Delegates stehen.
    Repeater {
        model: root.monitors.map(m => m.name)

        Item {
            id: mon

            required property string modelData
            readonly property var info: root.monitors.find(m => m.name === mon.modelData) ?? ({
                    "name": mon.modelData,
                    "number": "",
                    "x": 0,
                    "y": 0,
                    "w": 0,
                    "h": 0,
                    "primary": false
                })
            readonly property bool isSelected: modelData === root.selected
            readonly property bool isPrimary: info.primary === true
            readonly property real rw: Math.max(24, info.w * root.scale)
            readonly property real rh: Math.max(16, info.h * root.scale)

            x: root.px(info, "x")
            y: root.px(info, "y")
            width: rw
            height: rh
            z: isSelected ? 2 : 1

            // Füllfläche
            Rectangle {
                anchors.fill: parent
                radius: 5
                color: Theme.windowBg
                border.width: mon.isSelected ? 2 : 1
                border.color: mon.isSelected ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.15)
            }

            // Primäranzeige: dicke Oberkante (wie .monitor.primary)
            Rectangle {
                visible: mon.isPrimary
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 4
                color: Theme.dark ? Theme.windowFg : "#000000"
            }

            // Anzeigenummer
            Rectangle {
                anchors.centerIn: parent
                width: Math.max(18, label.implicitWidth + 8)
                height: width
                radius: width / 2
                color: "#dddddd"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: mon.info.number
                    color: "#000000"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    font.features: ({ "tnum": 1 })
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real startX: 0
                property real startY: 0
                property real origX: 0
                property real origY: 0
                property bool moved: false

                onPressed: m => {
                    root.monitorSelected(mon.modelData);
                    const p = mapToItem(root, m.x, m.y);
                    startX = p.x;
                    startY = p.y;
                    origX = mon.info.x;
                    origY = mon.info.y;
                    moved = false;
                }
                onPositionChanged: m => {
                    if (!pressed)
                        return;
                    const p = mapToItem(root, m.x, m.y);
                    const dx = (p.x - startX) / root.scale;
                    const dy = (p.y - startY) / root.scale;
                    if (!moved && Math.abs(p.x - startX) < 3 && Math.abs(p.y - startY) < 3)
                        return;
                    moved = true;
                    const snapped = root._snap(mon.modelData, origX + dx, origY + dy, mon.info.w, mon.info.h);
                    if (snapped.x !== mon.info.x || snapped.y !== mon.info.y)
                        root.monitorMoved(mon.modelData, snapped.x, snapped.y);
                }
            }
        }
    }

    // Rastet den gezogenen Monitor an den Kanten der übrigen ein
    function _snap(name, x, y, w, h) {
        const others = root.monitors.filter(m => m.name !== name);
        const major = others.length >= 2 ? dragThreshold / root.scale : Infinity;
        const minor = 5 / root.scale;
        let bestX = null, bestXd = Infinity, bestY = null, bestYd = Infinity;
        for (const o of others) {
            for (const cx of [o.x, o.x + o.w, o.x - w, o.x + o.w - w, o.x + o.w / 2 - w / 2]) {
                const d = Math.abs(x - cx);
                if (d < bestXd) {
                    bestXd = d;
                    bestX = cx;
                }
            }
            for (const cy of [o.y, o.y + o.h, o.y - h, o.y + o.h - h, o.y + o.h / 2 - h / 2]) {
                const d = Math.abs(y - cy);
                if (d < bestYd) {
                    bestYd = d;
                    bestY = cy;
                }
            }
        }
        let rx = x, ry = y;
        if (bestX !== null && bestXd <= major)
            rx = bestX;
        else if (bestX !== null && bestXd <= minor)
            rx = bestX;
        if (bestY !== null && bestYd <= major)
            ry = bestY;
        else if (bestY !== null && bestYd <= minor)
            ry = bestY;
        return { "x": Math.round(rx), "y": Math.round(ry) };
    }
}
