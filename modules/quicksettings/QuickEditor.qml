import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Bearbeitungsansicht der Quick-Settings: oben die aktuellen Kacheln (Minus entfernt, Ziehen ordnet um),
// darunter nach Kategorien alle verfügbaren Kacheln (Plus fügt hinzu, bereits eingebaute sind blass).
// Läuft unten in einen Verlauf zum Kartenhintergrund aus.
Item {
    id: root

    // [{ id, title, icon, category }]
    required property var catalog
    // id → Kachel auf diesem System nutzbar
    required property var available
    // Beschriftung je Kategorie-ID, in Anzeigereihenfolge
    readonly property var categories: [
        {
            "id": "connectivity",
            "title": "Verbindungen"
        },
        {
            "id": "device",
            "title": "Gerät"
        },
        {
            "id": "appearance",
            "title": "Darstellung"
        }
    ]

    readonly property real gap: Theme.spacingLg
    readonly property var order: SettingsService.quickToggles
    readonly property int rowHeight: Theme.quickToggleHeight + gap
    readonly property int fadeHeight: 72

    signal closeRequested

    function entry(id) {
        return catalog.find(c => c.id === id);
    }
    function usable(id) {
        return !!available[id];
    }
    // Liste der tatsächlich angezeigten Kachel-IDs (verfügbar und eingestellt)
    readonly property var activeIds: order.filter(id => usable(id) && entry(id))
    // Position in der Anzeige (Gitter) für eine Kachel-ID, -1 = nicht gezeigt
    function slotOf(id) {
        return activeIds.indexOf(id);
    }

    // ───────── Kopf ─────────

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.iconSize + 2 * Theme.iconButtonQuickPadding

        Text {
            anchors.centerIn: parent
            text: "Schnelleinstellungen"
            color: Theme.fgColor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeTitle4
            font.weight: Theme.fontWeightBold
        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "window-close-symbolic"
            iconSize: 12
            padding: Theme.basePadding * 1.5
            onClicked: root.closeRequested()
        }
    }

    // ───────── Inhalt ─────────

    Flickable {
        id: flick

        anchors.top: header.bottom
        anchors.topMargin: root.gap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: content.height + root.fadeHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        // Abzeichen ragen 4px über die Kachel: oberer Rand nicht abschneiden
        topMargin: 6

        ColumnLayout {
            id: content

            width: flick.width
            spacing: root.gap

            // Aktuelle Kacheln: Position per Reihenfolge, Ziehen sortiert um
            Item {
                id: current

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(1, Math.ceil(root.activeIds.length / 2)) * root.rowHeight - root.gap

                Repeater {
                    model: root.catalog

                    EditTile {
                        id: tile

                        required property var modelData
                        readonly property int slot: root.slotOf(modelData.id)
                        property real dragX: 0
                        property real dragY: 0

                        visible: slot >= 0
                        title: modelData.title
                        icon: modelData.icon
                        symbolic: modelData.symbolic ?? true
                        badge: "remove"
                        draggable: true
                        z: dragging ? 10 : 0
                        x: dragging ? dragX : (slot % 2) * (Theme.quickToggleWidth + root.gap)
                        y: dragging ? dragY : Math.floor(slot / 2) * root.rowHeight

                        Behavior on x {
                            enabled: (!tile.dragging) && !Theme.gameMode
                            NumberAnimation {
                                duration: Theme.durationButton
                                easing.type: Theme.easeOutQuad
                            }
                        }
                        Behavior on y {
                            enabled: (!tile.dragging) && !Theme.gameMode
                            NumberAnimation {
                                duration: Theme.durationButton
                                easing.type: Theme.easeOutQuad
                            }
                        }

                        onBadgeClicked: SettingsService.removeQuickToggle(modelData.id)

                        // Ziehen: ab 6px Bewegung; Zielposition aus dem Mittelpunkt der Kachel
                        property point pressPoint
                        property bool moved: false

                        Connections {
                            target: tile.mouse
                            function onPressed(m) {
                                tile.pressPoint = Qt.point(m.x, m.y);
                                tile.moved = false;
                            }
                            function onPositionChanged(m) {
                                if (!tile.mouse.pressed)
                                    return;
                                if (!tile.moved && Math.hypot(m.x - tile.pressPoint.x, m.y - tile.pressPoint.y) < 6)
                                    return;
                                if (!tile.moved) {
                                    tile.moved = true;
                                    tile.dragX = tile.x;
                                    tile.dragY = tile.y;
                                    tile.dragging = true;
                                }
                                const p = tile.mouse.mapToItem(current, m.x, m.y);
                                tile.dragX = p.x - tile.pressPoint.x;
                                tile.dragY = p.y - tile.pressPoint.y;
                                const cx = tile.dragX + tile.width / 2;
                                const cy = tile.dragY + tile.height / 2;
                                const col = cx > current.width / 2 ? 1 : 0;
                                const row = Math.max(0, Math.floor(cy / root.rowHeight));
                                const target = Math.min(root.activeIds.length - 1, row * 2 + col);
                                if (target !== tile.slot)
                                    SettingsService.moveQuickToggle(tile.modelData.id, root.moveIndex(tile.modelData.id, target));
                            }
                            function onReleased() {
                                tile.dragging = false;
                            }
                            function onCanceled() {
                                tile.dragging = false;
                            }
                        }
                    }
                }
            }

            // Kategorien mit allen verfügbaren Kacheln
            Repeater {
                model: root.categories

                Rectangle {
                    id: section

                    required property var modelData
                    readonly property var items: root.catalog.filter(c => c.category === modelData.id && root.usable(c.id))
                    readonly property real pad: Theme.spacingXl * 0.75
                    readonly property real tileWidth: (width - 2 * pad - root.gap) / 2

                    visible: items.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: label.height + pad * 2 + Math.ceil(items.length / 2) * root.rowHeight - root.gap + root.gap
                    radius: Theme.radiusQuickToggleMenu
                    color: Theme.menuItemBg

                    Text {
                        id: label

                        x: section.pad + Theme.basePadding
                        y: section.pad
                        text: section.modelData.title
                        color: Theme.transparentize(Theme.fgColor, 0.45)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeHeading
                        font.weight: Theme.fontWeightBold
                    }

                    Repeater {
                        model: section.items

                        EditTile {
                            required property var modelData
                            required property int index
                            readonly property bool added: root.slotOf(modelData.id) >= 0

                            width: section.tileWidth
                            x: section.pad + (index % 2) * (section.tileWidth + root.gap)
                            y: section.pad + label.height + root.gap + Math.floor(index / 2) * root.rowHeight
                            title: modelData.title
                            icon: modelData.icon
                            symbolic: modelData.symbolic ?? true
                            dimmed: added
                            badge: "add"
                            onBadgeClicked: SettingsService.addQuickToggle(modelData.id)
                            onClicked: SettingsService.addQuickToggle(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // Verlauf zum Kartenhintergrund; fängt keine Klicks ab
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.fadeHeight
        enabled: false
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(Theme.menuBg.r, Theme.menuBg.g, Theme.menuBg.b, 0)
            }
            GradientStop {
                position: 1
                color: Theme.menuBg
            }
        }
    }

    // Index in der vollständigen Liste (inkl. nicht verfügbarer Kacheln) für eine Zielposition der sichtbaren
    function moveIndex(id, visibleTarget) {
        const others = order.filter(t => t !== id);
        const shown = others.filter(t => usable(t) && entry(t));
        if (visibleTarget >= shown.length)
            return others.length;
        return others.indexOf(shown[visibleTarget]);
    }
}
