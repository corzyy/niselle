import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Zwischenablage-Verlauf als eigenes Fenster am Mauszeiger (`niselle clipboard`, Super+V). Ein durchsichtiges Vollbild-
// Fenster fängt Klicks daneben (schließen) und den Tastaturfokus ab; die Karte sitzt am Zeiger und weicht an den
// Rand aus. Tippen filtert, Pfeile wählen, Enter legt den Eintrag in die Zwischenablage, Entf löscht ihn, Esc schließt.
PanelWindow {
    id: root

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool shown: ClipboardService.popupOpen && ClipboardService.popupScreen !== "" && ClipboardService.popupScreen === screenName

    readonly property real cardWidth: 400
    readonly property real textRowHeight: 40
    readonly property real metaRowHeight: 52
    readonly property real thumbRowHeight: 76
    readonly property real headerHeight: 52
    readonly property real margin: 12
    readonly property var filtered: {
        const terms = search.text.toLowerCase().split(/\s+/).filter(t => t !== "");
        return ClipboardService.entries.filter(e => terms.every(t => e.text.toLowerCase().indexOf(t) >= 0));
    }
    function rowHeightOf(e) {
        if (e.preview !== "" && ClipboardService.thumbs[e.id])
            return thumbRowHeight;
        return e.meta !== "" ? metaRowHeight : textRowHeight;
    }
    readonly property real rowsHeight: {
        // ClipboardService.thumbs: Höhe ändert sich, sobald Vorschauen fertig sind
        const t = ClipboardService.thumbs;
        let h = 0;
        for (const e of filtered)
            h += rowHeightOf(e);
        return Math.max(textRowHeight, h);
    }
    readonly property real cardHeight: Math.min(440, headerHeight + rowsHeight + 2 * 8 + 8)

    // Unter dem Zeiger, bei Platzmangel darüber bzw. links davon; immer im Bildschirm
    readonly property real cardX: {
        const p = ClipboardService.popupPoint.x;
        const x = p + cardWidth + margin > width ? p - cardWidth : p;
        return Math.max(margin, Math.min(x, width - cardWidth - margin));
    }
    readonly property real cardY: {
        const p = ClipboardService.popupPoint.y;
        const y = p + cardHeight + margin > height ? p - cardHeight : p;
        return Math.max(margin, Math.min(y, height - cardHeight - margin));
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-clipboard"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            search.text = "";
            list.currentIndex = 0;
            search.forceActiveFocus();
        }
    }

    function activate(entry) {
        ClipboardService.copy(entry);
        ClipboardService.closePopup();
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        acceptedButtons: Qt.AllButtons
        onPressed: ClipboardService.closePopup()
    }

    ShadowRect {
        id: card

        x: root.cardX
        y: root.cardY
        width: root.cardWidth
        height: root.cardHeight
        radius: Theme.radiusPopover
        color: Theme.popoverBg
        border.width: Theme.popoverBorderWidth
        border.color: Theme.alpha(Theme.popoverFg, 0.1)
        shadowBlur: 24
        shadowOffsetY: 4
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationPopover
                easing.type: Theme.easeOutQuad
            }
        }
        Behavior on scale {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationPopover
                easing.type: Theme.easeOutQuad
            }
        }

        // Klicks auf die Karte nicht an den Hintergrund weitergeben
        MouseArea {
            anchors.fill: parent
        }

        // Suchfeld
        Rectangle {
            id: field

            x: 8
            y: 8
            width: parent.width - 16
            height: root.headerHeight - 12
            radius: Theme.radiusEntry
            color: Theme.entryBg

            Icon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "edit-paste-symbolic"
                size: 16
                color: Theme.entryFgIdle
            }

            TextInput {
                id: search

                anchors.left: searchIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.entryFg
                selectionColor: Theme.entrySelection
                selectedTextColor: Theme.fgColor
                clip: true
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
                onTextChanged: list.currentIndex = 0

                Keys.onPressed: event => {
                    event.accepted = true;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        ClipboardService.closePopup();
                        break;
                    case Qt.Key_Down:
                    case Qt.Key_Tab:
                        list.currentIndex = Math.min(list.currentIndex + 1, root.filtered.length - 1);
                        break;
                    case Qt.Key_Up:
                    case Qt.Key_Backtab:
                        list.currentIndex = Math.max(list.currentIndex - 1, 0);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (root.filtered.length > 0)
                            root.activate(root.filtered[list.currentIndex]);
                        break;
                    case Qt.Key_Delete:
                        if (search.text === "" && root.filtered.length > 0)
                            ClipboardService.remove(root.filtered[list.currentIndex]);
                        else
                            event.accepted = false;
                        break;
                    default:
                        event.accepted = false;
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: search.text === ""
                    text: "Search clipboard history"
                    color: Theme.entryHint
                    elide: Text.ElideRight
                    font: search.font
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        ListView {
            id: list

            x: 8
            y: root.headerHeight
            width: parent.width - 16
            height: parent.height - root.headerHeight - 8
            clip: true
            model: root.filtered
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                readonly property bool current: ListView.isCurrentItem
                readonly property string thumb: ClipboardService.thumbs[modelData.id] ?? ""
                readonly property bool hasThumb: modelData.preview !== "" && thumb !== ""

                width: list.width
                height: root.rowHeightOf(modelData)
                radius: Theme.radiusMenuItem
                color: current || rowMouse.containsMouse ? Theme.alpha(Theme.popoverFg, 0.1) : "transparent"

                // Vorschau (Bild, Videostandbild) oder Symbol
                Item {
                    id: lead
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.hasThumb ? 88 : 24
                    height: row.hasThumb ? 60 : 24

                    Rectangle {
                        anchors.fill: parent
                        visible: row.hasThumb
                        radius: 8
                        color: Theme.alpha(Theme.popoverFg, 0.08)
                    }
                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        visible: row.hasThumb && status === Image.Ready
                        source: row.hasThumb ? row.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(176, 120)
                        asynchronous: true
                        cache: false
                    }
                    // Abspielsymbol auf Videovorschauen
                    Icon {
                        anchors.centerIn: parent
                        visible: row.hasThumb && row.modelData.preview === "video" && thumbImage.status === Image.Ready
                        name: "media-playback-start-symbolic"
                        color: "#ffffff"
                        size: 20
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !row.hasThumb
                        name: row.modelData.icon
                        color: Theme.popoverFg
                        size: 16
                    }
                }

                Column {
                    anchors.left: lead.right
                    anchors.leftMargin: 10
                    anchors.right: removeButton.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: row.modelData.label
                        color: Theme.popoverFg
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                    }
                    Text {
                        width: parent.width
                        visible: row.modelData.meta !== ""
                        text: row.modelData.meta
                        color: Theme.alpha(Theme.popoverFg, 0.6)
                        elide: Text.ElideMiddle
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase * 0.85
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.currentIndex = row.index
                    onClicked: root.activate(row.modelData)
                }

                // Eintrag löschen
                Rectangle {
                    id: removeButton
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    visible: row.current || rowMouse.containsMouse
                    color: removeMouse.containsMouse ? Theme.alpha(Theme.popoverFg, 0.15) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        name: "window-close-symbolic"
                        color: Theme.popoverFg
                        size: 12
                    }
                    MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ClipboardService.remove(row.modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                text: ClipboardService.entries.length === 0 ? "Nothing copied yet" : "No matches"
                color: Theme.alpha(Theme.popoverFg, 0.6)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
            }
        }
    }
}
