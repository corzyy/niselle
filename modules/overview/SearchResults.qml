import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Suchergebnisse der Übersicht (#searchResults / .search-section) [search.js: SearchResultsView, _search-results.scss].
// Pro Anbieter ein Abschnitt (search-section, Column mit Abstand 18, danach ein leerer Trenner der Höhe 8):
//   Apps als Raster (eine Reihe, [search.js: GridSearchResults])
//   Übrige Anbieter als Karte (search-section-content): links die Anbieter-Kachel (search-provider-icon, Icon 32,
//   Name und „N weitere“), rechts die Ergebniszeilen (list-search-result, Icon 24, Titel + Beschreibung)
//   [search.js: ListSearchResults, ProviderInfo, ListSearchResult]
// Ohne Treffer mittig „Keine Ergebnisse“ samt Ladekreis.
//
// Auswahl: der erste Treffer des ersten Anbieters ist vorausgewählt [search.js: _maybeSetInitialSelection]; Pfeile
// bewegen die Auswahl (im Raster auch waagerecht), Enter aktiviert. `opacity`/Sichtbarkeit setzt die Übersicht.
Item {
    id: root

    // Abschnitte in Reihenfolge mit Startindex (für die Auswahl)
    readonly property var sections: {
        const list = [];
        let start = 0;
        for (const p of SearchService.providers) {
            const results = SearchService.results(p.id);
            if (results.length === 0)
                continue;
            list.push({
                "provider": p,
                "results": results,
                "start": start,
                "more": SearchService.moreCount(p.id)
            });
            start += results.length;
        }
        return {
            "list": list,
            "total": start
        };
    }
    readonly property int total: sections.total
    readonly property bool searching: SearchService.active
    readonly property bool pending: SearchService.inProgress

    property int selected: 0
    onTotalChanged: root.selected = root.total > 0 ? 0 : -1

    function sectionOf(index) {
        for (const s of root.sections.list) {
            if (index >= s.start && index < s.start + s.results.length)
                return s;
        }
        return null;
    }
    function resultAt(index) {
        const s = root.sectionOf(index);
        return s ? {
            "provider": s.provider,
            "result": s.results[index - s.start]
        } : null;
    }
    function moveSelection(dx, dy) {
        if (root.total === 0)
            return;
        if (dy !== 0) {
            root.selected = Math.max(0, Math.min(root.selected + dy, root.total - 1));
            return;
        }
        if (dx !== 0) {
            const s = root.sectionOf(root.selected);
            if (s && s.provider.grid) {
                const lo = s.start;
                const hi = s.start + s.results.length - 1;
                root.selected = Math.max(lo, Math.min(root.selected + dx, hi));
            }
        }
    }
    function resetSelection() {
        root.selected = root.total > 0 ? 0 : -1;
    }
    function activateSelected() {
        const r = root.resultAt(root.selected);
        if (!r)
            return;
        if (SearchService.activate(r.provider.id, r.result))
            OverviewService.hide();
    }
    function _activate(providerId, result) {
        if (SearchService.activate(providerId, result))
            OverviewService.hide();
    }

    // Höhe, die der Inhalt im Panel braucht (das Overlay begrenzt sie auf den Platz unter dem Suchfeld)
    readonly property real wantedHeight: (root.total > 0 ? content.height : 0) + 2 * Theme.searchOverlayPadding

    function _providerAction(providerId) {
        if (SearchService.providerAction(providerId))
            OverviewService.hide();
    }

    Flickable {
        id: view
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Ausgewähltes Ergebnis per Pfeiltasten in den sichtbaren Bereich holen
        function ensureVisible(item) {
            const top = item.mapToItem(content, 0, 0).y;
            const bottom = top + item.height;
            if (top < view.contentY)
                view.contentY = top;
            else if (bottom > view.contentY + view.height)
                view.contentY = bottom - view.height;
        }

        Column {
            id: content
            width: view.width
            spacing: Theme.searchSectionSpacing

            Repeater {
                model: root.sections.list

                Column {
                    id: sectionDelegate

                    required property var modelData
                    required property int index

                    readonly property var provider: modelData.provider
                    readonly property int start: modelData.start

                    width: content.width
                    spacing: Theme.basePadding

                    // Kopfzeile: Anbietername, rechts optional ein Knopf („In Dateien suchen“)
                    Item {
                        visible: !sectionDelegate.provider.grid && sectionDelegate.provider.id !== "calculator"
                        width: parent.width
                        height: visible ? Math.max(headerLabel.implicitHeight, headerButton.visible ? headerButton.implicitHeight : 0) : 0

                        Text {
                            id: headerLabel
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.baseMargin * 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: sectionDelegate.provider.name + (sectionDelegate.modelData.more > 0 ? " · " + sectionDelegate.modelData.more + " weitere" : "")
                            color: Theme.systemFg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            font.weight: Theme.fontWeightBold
                        }

                        Button {
                            id: headerButton
                            visible: !!sectionDelegate.provider.actionLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: sectionDelegate.provider.actionLabel ?? ""
                            fg: Theme.systemFg
                            paddingV: Theme.baseMargin
                            paddingH: Theme.basePadding * 2
                            onClicked: root._providerAction(sectionDelegate.provider.id)
                        }
                    }

                    // Apps: Raster ohne Karte [search.js: GridSearchResults]
                    Row {
                        visible: sectionDelegate.provider.grid
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.baseMargin

                        Repeater {
                            model: sectionDelegate.provider.grid ? sectionDelegate.modelData.results : []

                            Item {
                                id: tileCell

                                required property var modelData
                                required property int index

                                readonly property int globalIndex: sectionDelegate.start + index
                                readonly property bool isSelected: root.selected === globalIndex

                                width: gridTile.naturalSize
                                height: gridTile.naturalSize

                                AppTile {
                                    id: gridTile
                                    anchors.fill: parent
                                    icon: tileCell.modelData.entry ? (tileCell.modelData.entry.icon || "application-x-executable") : "application-x-executable"
                                    label: tileCell.modelData.name
                                    iconSize: Theme.iconSizeLarge * 1.5
                                    expandOnHover: false
                                    hovered: tileMouse.containsMouse
                                    checked: tileCell.isSelected
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: {
                                        if (containsMouse)
                                            root.selected = tileCell.globalIndex;
                                    }
                                    onClicked: root._activate(sectionDelegate.provider.id, tileCell.modelData)
                                }
                            }
                        }
                    }

                    // Rechner: große Ergebniskarte mit Rechnung darüber, Klick kopiert das Ergebnis
                    Repeater {
                        model: sectionDelegate.provider.id === "calculator" ? sectionDelegate.modelData.results : []

                        Tile {
                            id: calcTile

                            required property var modelData
                            required property int index

                            readonly property int globalIndex: sectionDelegate.start + index

                            width: sectionDelegate.width
                            interactive: true
                            activeFocusOnTab: false
                            raised: false
                            bg: Theme.systemBg
                            radius: Theme.radiusSearchItem
                            padding: Theme.basePadding * 2
                            checked: root.selected === calcTile.globalIndex
                            onHoveredChanged: {
                                if (calcTile.hovered)
                                    root.selected = calcTile.globalIndex;
                            }
                            onClicked: root._activate("calculator", calcTile.modelData)

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: calcColumn.implicitHeight

                                Column {
                                    id: calcColumn
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: Theme.baseMargin

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: calcTile.modelData.description
                                        color: Theme.searchDescriptionFg
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSizeBase
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: calcTile.modelData.name
                                        color: Theme.systemFg
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.searchCalcFontSize
                                        font.weight: Theme.fontWeightBold
                                    }
                                }

                                Icon {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "edit-copy-symbolic"
                                    color: Theme.systemFg
                                    size: Theme.iconSize
                                }
                            }
                        }
                    }

                    // Liste: eine Karte, die Ergebniszeilen mit Trennlinien enthält
                    Rectangle {
                        visible: !sectionDelegate.provider.grid && sectionDelegate.provider.id !== "calculator"
                        width: parent.width
                        height: visible ? listColumn.height + 2 * Theme.baseMargin : 0
                        radius: Theme.radiusSearchSection
                        color: Theme.glass(Theme.systemBg)

                        Column {
                            id: listColumn
                            x: Theme.baseMargin
                            y: Theme.baseMargin
                            width: parent.width - 2 * Theme.baseMargin
                            spacing: Theme.searchListSpacing

                            Repeater {
                                model: sectionDelegate.provider.grid || sectionDelegate.provider.id === "calculator" ? [] : sectionDelegate.modelData.results

                                Tile {
                                    id: rowTile

                                    required property var modelData
                                    required property int index

                                    readonly property int globalIndex: sectionDelegate.start + index

                                    width: listColumn.width
                                    interactive: true
                                    activeFocusOnTab: false
                                    raised: false
                                    bg: Theme.systemBg
                                    radius: Theme.radiusSearchItem
                                    padding: Theme.tilePadding
                                    checked: root.selected === rowTile.globalIndex
                                    onHoveredChanged: {
                                        if (rowTile.hovered)
                                            root.selected = rowTile.globalIndex;
                                    }
                                    onClicked: root._activate(sectionDelegate.provider.id, rowTile.modelData)

                                    RowLayout {
                                        id: rowContent

                                        readonly property bool hasDescription: rowTile.modelData.description !== ""

                                        Layout.fillWidth: true
                                        spacing: Theme.searchListContentSpacing

                                        // Titel mit führendem Symbol (list-search-result-title, Abstand 12). Ohne Beschreibung füllt er
                                        // die Zeile, mit Beschreibung bekommt er höchstens 60 % – lange Texte (Zwischenablage) werden gekürzt
                                        // statt am Rand des Panels abgeschnitten.
                                        RowLayout {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.fillWidth: !rowContent.hasDescription
                                            Layout.maximumWidth: rowContent.hasDescription ? rowTile.width * 0.6 : rowTile.width
                                            spacing: Theme.searchListTitleSpacing

                                            Icon {
                                                Layout.alignment: Qt.AlignVCenter
                                                name: rowTile.modelData.icon
                                                color: Theme.systemFg
                                                size: Theme.searchListIconSize
                                                symbolic: rowTile.modelData.symbolic !== false && !(rowTile.modelData.icon && rowTile.modelData.icon.includes("/"))
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.fillWidth: true
                                                text: rowTile.modelData.name
                                                textFormat: Text.PlainText
                                                color: Theme.systemFg
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pointSize: Theme.fontSizeBase
                                                font.weight: Theme.fontWeightNormal
                                            }
                                        }

                                        // Beschreibung (list-search-result-description)
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            visible: rowContent.hasDescription
                                            text: SearchService.highlight(rowTile.modelData.description)
                                            textFormat: Text.RichText
                                            color: Theme.searchDescriptionFg
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pointSize: Theme.fontSizeBase
                                        }
                                    }

                                    onCheckedChanged: if (checked) view.ensureVisible(rowTile)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Kein Treffer / läuft noch [search.js: _updateSearchProgress]
    Column {
        anchors.centerIn: parent
        visible: root.searching && root.total === 0
        spacing: Theme.searchStatusSpacing

        Spinner {
            anchors.horizontalCenter: parent.horizontalCenter
            running: root.pending
            size: Theme.searchSpinnerSize
            color: Theme.systemFg
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.pending ? "Suche läuft …" : "Keine Ergebnisse"
            color: Theme.searchStatusFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeTitle1
            font.weight: Theme.fontWeightExtraBold
        }
    }
}
