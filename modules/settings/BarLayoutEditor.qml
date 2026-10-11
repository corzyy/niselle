import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components

// Anordnung der Menüleiste: Vorschau mit drei Zonen (links, Mitte, rechts) und einer Ablage für ausgeblendete Elemente.
// Ein Klick wählt ein Element; die Leiste darunter verschiebt es (Reihenfolge, Zone, ausblenden). Änderungen gelten sofort.
Item {
    id: root

    property string selected: ""

    readonly property string selectedZone: selected === "" ? "" : SettingsService.barZoneOf(selected)
    readonly property var selectedItem: SettingsService.barItems.find(i => i.id === selected) ?? null
    readonly property var hidden: SettingsService.barItems.filter(i => SettingsService.barZoneOf(i.id) === "")

    function titleOf(id) {
        return SettingsService.barItems.find(i => i.id === id)?.title ?? id;
    }
    function iconOf(id) {
        return SettingsService.barItems.find(i => i.id === id)?.icon ?? "";
    }
    function moveTo(zone) {
        SettingsService.moveBarItem(selected, zone, undefined);
    }

    // Ziehen: Chip folgt dem Zeiger (Ghost), eine Markierung zeigt die Einfügestelle
    property string dragId: ""
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property var dropBox: null
    property int dropIndex: 0
    property rect dropMarker: Qt.rect(0, 0, 0, 0)

    readonly property var boxes: [leftBox, centerBox, rightBox, hiddenBox]

    function beginDrag(id, offsetX, offsetY) {
        selected = id;
        dragId = id;
        dragOffsetX = offsetX;
        dragOffsetY = offsetY;
        dragging = true;
    }
    function updateDrag(px, py) {
        dragX = px;
        dragY = py;
        let found = null;
        for (const box of boxes) {
            const p = root.mapToItem(box, px, py);
            if (p.x >= 0 && p.y >= 0 && p.x < box.width && p.y < box.height) {
                found = box;
                break;
            }
        }
        // Pflichtelemente lassen sich nicht ausblenden
        if (found && found.zone === "" && (selectedItem?.required ?? false))
            found = null;
        dropBox = found;
        if (!found)
            return;
        const flow = found.flow;
        const fp = root.mapToItem(flow, px, py);
        const chips = [];
        for (const c of flow.children) {
            if (c.itemId !== undefined && c.itemId !== dragId && c.visible)
                chips.push(c);
        }
        let index = 0;
        for (const c of chips) {
            if (fp.y > c.y + c.height || (fp.y >= c.y && fp.x > c.x + c.width / 2))
                index++;
        }
        dropIndex = index;
        let mx, my, mh = 32;
        if (index < chips.length) {
            mx = chips[index].x - 4;
            my = chips[index].y;
        } else if (chips.length > 0) {
            const last = chips[chips.length - 1];
            mx = last.x + last.width + 2;
            my = last.y;
        } else {
            mx = 0;
            my = 0;
        }
        const m = flow.mapToItem(root, mx, my);
        dropMarker = Qt.rect(m.x, m.y, 3, mh);
    }
    function endDrag(commit) {
        if (commit && dropBox)
            SettingsService.moveBarItem(dragId, dropBox.zone, dropIndex);
        dragging = false;
        dragId = "";
        dropBox = null;
    }

    implicitHeight: content.implicitHeight

    component Chip: Rectangle {
        id: chip

        required property string itemId
        property bool interactive: true
        readonly property bool isSelected: root.selected === itemId

        opacity: root.dragging && root.dragId === itemId && interactive ? 0.3 : 1
        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 32
        radius: Theme.radiusPill
        color: isSelected ? Theme.accentColor : Theme.alpha(Theme.windowFg, chipMouse.containsMouse ? 0.14 : 0.08)
        border.width: 1
        border.color: isSelected ? "transparent" : Theme.alpha(Theme.windowFg, 0.12)

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationTile
            }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            Icon {
                name: root.iconOf(chip.itemId)
                size: 16
                color: chip.isSelected ? Theme.accentFg : Theme.windowFg
            }
            Text {
                text: root.titleOf(chip.itemId)
                color: chip.isSelected ? Theme.accentFg : Theme.windowFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
                font.weight: chip.isSelected ? Theme.fontWeightBold : Theme.fontWeightNormal
            }
        }
        MouseArea {
            id: chipMouse

            property real pressX: 0
            property real pressY: 0
            property bool moved: false

            anchors.fill: parent
            hoverEnabled: true
            // Die scrollbare Seite (Flickable) darf den Zug nicht übernehmen
            preventStealing: true
            enabled: chip.interactive
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: m => {
                pressX = m.x;
                pressY = m.y;
                moved = false;
            }
            onPositionChanged: m => {
                if (!pressed)
                    return;
                if (!moved && Math.abs(m.x - pressX) + Math.abs(m.y - pressY) > 6) {
                    moved = true;
                    root.beginDrag(chip.itemId, pressX, pressY);
                }
                if (moved) {
                    const p = mapToItem(root, m.x, m.y);
                    root.updateDrag(p.x, p.y);
                }
            }
            onReleased: if (moved)
                root.endDrag(true)
            onCanceled: if (moved)
                root.endDrag(false)
            onClicked: if (!moved)
                root.selected = root.selected === chip.itemId ? "" : chip.itemId
        }
    }

    // Eine Zone: Beschriftung und Chips; ein Klick auf die leere Fläche legt das gewählte Element hier ab
    component ZoneBox: Rectangle {
        id: box

        required property string zone
        required property string label
        readonly property var ids: SettingsService.barLayout[zone]
        readonly property bool target: root.selected !== "" && root.selectedZone !== zone
        readonly property bool dropping: root.dragging && root.dropBox === box
        property alias flow: chipFlow

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: Math.max(84, boxCol.implicitHeight + 20)
        radius: Theme.radiusButton
        color: Theme.alpha(Theme.windowFg, dropping || (target && boxMouse.containsMouse) ? 0.12 : 0.05)
        border.width: 1
        border.color: dropping ? Theme.accentColor : target ? Theme.alpha(Theme.accentColor, 0.7) : Theme.alpha(Theme.windowFg, 0.1)

        MouseArea {
            id: boxMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: box.target && !root.dragging
            cursorShape: Qt.PointingHandCursor
            onClicked: root.moveTo(box.zone)
        }

        ColumnLayout {
            id: boxCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: box.label
                color: Theme.alpha(Theme.windowFg, 0.55)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
            }
            Flow {
                id: chipFlow
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: box.ids

                    Chip {
                        required property string modelData
                        itemId: modelData
                    }
                }
            }
            Text {
                visible: box.ids.length === 0
                text: root.dragging ? "Drop here" : box.target ? "Click to move here" : "Empty"
                color: Theme.alpha(Theme.windowFg, 0.4)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // Vorschau der Leiste
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: zones.implicitHeight + 24
            radius: Theme.radiusCard * 1.25
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.dark ? Theme.alpha(Theme.windowFg, 0.05) : Theme.alpha(Theme.windowFg, 0.07)

            RowLayout {
                id: zones
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                ZoneBox {
                    id: leftBox
                    zone: "left"
                    label: "Left"
                }
                ZoneBox {
                    id: centerBox
                    zone: "center"
                    label: "Center"
                }
                ZoneBox {
                    id: rightBox
                    zone: "right"
                    label: "Right"
                }
            }
        }

        // Ablage: ausgeblendete Elemente
        Rectangle {
            id: hiddenBox

            readonly property string zone: ""
            property alias flow: hiddenFlow

            Layout.fillWidth: true
            implicitHeight: hiddenCol.implicitHeight + 24
            radius: Theme.radiusCard * 1.25
            color: root.dragging && root.dropBox === hiddenBox ? Theme.alpha(Theme.windowFg, 0.08) : "transparent"
            border.width: 1
            border.color: root.dragging && root.dropBox === hiddenBox ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.14)

            ColumnLayout {
                id: hiddenCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "Hidden"
                    color: Theme.alpha(Theme.windowFg, 0.55)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                }
                Flow {
                    id: hiddenFlow
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.hidden

                        Chip {
                            required property var modelData
                            itemId: modelData.id
                        }
                    }
                }
                Text {
                    visible: root.hidden.length === 0
                    text: "Everything is shown"
                    color: Theme.alpha(Theme.windowFg, 0.4)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Drag items to rearrange or hide them."
                elide: Text.ElideRight
                color: Theme.alpha(Theme.windowFg, 0.6)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
            }
            Button {
                text: "Reset"
                onClicked: SettingsService.resetBarLayout()
            }
        }
    }

    // Einfügemarke und Ghost beim Ziehen
    Rectangle {
        visible: root.dragging && root.dropBox !== null
        x: root.dropMarker.x
        y: root.dropMarker.y
        width: root.dropMarker.width
        height: root.dropMarker.height
        radius: width / 2
        color: Theme.accentColor
        z: 99
    }
    Chip {
        visible: root.dragging
        interactive: false
        itemId: root.dragId
        x: root.dragX - root.dragOffsetX
        y: root.dragY - root.dragOffsetY
        opacity: 0.9
        z: 100
    }
}
