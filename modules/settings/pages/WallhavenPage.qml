import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.services
import qs.components

// Wallhaven-Browser im Stil von „WSelector“: obere Leiste (Start, Suche, Neu laden, Sortierung),
// Raster mit Miniaturen und ein Preferences-Fenster für Kategorien und Inhaltsfilter.
// Ein Klick auf eine Miniatur lädt das Bild in den Wallpaper-Ordner und wendet es an (inkl. Matugen).
// API: https://wallhaven.cc/help/api
Item {
    id: root

    readonly property string apiBase: "https://wallhaven.cc/api/v1/search"

    // ───────── Filter ─────────
    property string searchText: ""
    property string sorting: "random"
    property string topRange: "1M"
    property bool catGeneral: true
    property bool catAnime: true
    property bool catPeople: true
    property bool puritySfw: true
    property bool puritySketchy: false
    property string atleast: "1920x1080"
    property string ratio: "16x9"

    readonly property string categories: (catGeneral ? "1" : "0") + (catAnime ? "1" : "0") + (catPeople ? "1" : "0")
    // sfw-sketchy-nsfw; NSFW bleibt aus
    readonly property string purity: (puritySfw ? "1" : "0") + (puritySketchy ? "1" : "0") + "0"

    readonly property var sortingOptions: [
        { "id": "random", "label": "Random" },
        { "id": "toplist", "label": "Top List" },
        { "id": "date_added", "label": "Date Added" },
        { "id": "relevance", "label": "Relevance" },
        { "id": "views", "label": "Most Viewed" },
        { "id": "favorites", "label": "Most Favorited" }
    ]

    function sortLabel() {
        for (let i = 0; i < root.sortingOptions.length; i++)
            if (root.sortingOptions[i].id === root.sorting)
                return root.sortingOptions[i].label;
        return "Random";
    }

    // ───────── Zustand ─────────
    property var results: []
    property int page: 0
    property bool loading: false
    property bool loadingMore: false
    property string error: ""
    property int _pendingPage: 0
    property string applying: ""
    property bool sortOpen: false
    property bool prefsOpen: false
    // Registerkarte im Preferences-Fenster: "categories" | "safety"
    property string prefsTab: "categories"

    function buildUrl(p) {
        const parts = ["page=" + p, "sorting=" + root.sorting, "categories=" + root.categories, "purity=" + root.purity];
        if (root.sorting === "toplist")
            parts.push("topRange=" + root.topRange);
        if (root.searchText.trim() !== "")
            parts.push("q=" + encodeURIComponent(root.searchText.trim()));
        if (root.atleast !== "")
            parts.push("atleast=" + root.atleast);
        if (root.ratio !== "")
            parts.push("ratios=" + root.ratio);
        return root.apiBase + "?" + parts.join("&");
    }

    function startSearch() {
        root.page = 0;
        root.results = [];
        root.fetchPage();
    }

    function fetchPage() {
        if (root.loading || root.loadingMore)
            return;
        const next = root.page + 1;
        root._pendingPage = next;
        root.error = "";
        if (next === 1)
            root.loading = true;
        else
            root.loadingMore = true;
        api.command = ["sh", "-c", 'command -v curl >/dev/null 2>&1 || { echo "curl is not installed" >&2; exit 1; }; curl -fsSL "$1"', "sh", root.buildUrl(next)];
        api.running = true;
    }

    function applyResult(item) {
        if (root.applying !== "")
            return;
        root.applying = item.id;
        root.error = "";
        download.command = ["sh", "-c", 'pics=$(xdg-user-dir PICTURES 2>/dev/null); [ -n "$pics" ] || pics="$HOME/Pictures"; dir="$pics/wallpapers"; mkdir -p "$dir"; out="$dir/wallhaven-$2.${1##*.}"; curl -fsSL "$1" -o "$out" && printf "%s" "$out"', "sh", item.path, item.id];
        download.running = true;
    }

    Process {
        id: api
        stderr: StdioCollector {
            id: apiErr
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                root.loadingMore = false;
                let items = null;
                try {
                    const d = JSON.parse(text);
                    items = d.data;
                } catch (e) {
                    items = null;
                }
                if (!items) {
                    root.error = apiErr.text.trim() !== "" ? apiErr.text.trim() : "Wallhaven request failed";
                    return;
                }
                if (root._pendingPage <= 1)
                    root.results = items;
                else
                    root.results = root.results.concat(items);
                root.page = root._pendingPage;
                if (items.length === 0)
                    root.error = "No results";
            }
        }
    }

    Process {
        id: download
        stderr: StdioCollector {
            id: downloadErr
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                root.applying = "";
                if (path === "") {
                    root.error = downloadErr.text.trim() !== "" ? downloadErr.text.trim() : "Download failed";
                    return;
                }
                SettingsService.set("wallpaper", path);
                SettingsService.set("wallpaperHistory", [path].concat(SettingsService.wallpaperHistory.filter(p => p !== path)).slice(0, 50));
                setWallpaper.command = ["sh", "-c", 'command -v awww >/dev/null 2>&1 && awww img --transition-type grow --transition-pos center --transition-duration 1.2 --transition-fps 60 "$1"', "sh", path];
                setWallpaper.running = true;
            }
        }
    }

    Process {
        id: setWallpaper
        onExited: {
            WallpaperService.refresh();
            if (SettingsService.useMatugen && MatugenService.available)
                MatugenService.regenerate();
        }
    }

    Component.onCompleted: root.startSearch()

    // ───────── Obere Leiste ─────────
    Item {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60

        IconButton {
            id: homeButton
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            icon: "go-home-symbolic"
            flat: true
            padding: 9
            onClicked: root.startSearch()
        }

        // Sortierung: „Sort by: <Wert> ▾“
        Item {
            id: sortButton
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: sortRow.implicitWidth + 26
            height: 38
            readonly property bool open: root.sortOpen

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: sortButton.open ? Theme.alpha(Theme.windowFg, 0.14) : (sortMouse.containsMouse ? Theme.alpha(Theme.windowFg, 0.10) : Theme.alpha(Theme.windowFg, 0.06))
                border.width: 1
                border.color: Theme.alpha(Theme.windowFg, 0.12)
            }
            Row {
                id: sortRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sort by:"
                    color: Theme.alpha(Theme.windowFg, 0.6)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sortLabel()
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "pan-down-symbolic"
                    color: Theme.alpha(Theme.windowFg, 0.75)
                }
            }
            MouseArea {
                id: sortMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.sortOpen = !root.sortOpen
            }
        }

        IconButton {
            id: refreshButton
            anchors.right: sortButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            icon: "view-refresh-symbolic"
            flat: true
            padding: 9
            onClicked: root.startSearch()
        }

        // Suchfeld mit Lupe
        Item {
            id: searchBox
            anchors.left: homeButton.right
            anchors.leftMargin: 12
            anchors.right: refreshButton.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 38

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusEntry
                color: Theme.entryBg
                border.width: 1
                border.color: searchEntry.focused ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.12)
            }
            Icon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "system-search-symbolic"
                color: Theme.alpha(Theme.windowFg, 0.55)
            }
            Entry {
                id: searchEntry
                anchors.left: searchIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "Search wallpapers…"
                text: root.searchText
                onTextChanged: root.searchText = text
                onAccepted: root.startSearch()
            }
        }
    }

    // Dropdown der Sortierung (im Seitenbereich, damit es nicht beschnitten wird)
    Item {
        id: sortLayer
        anchors.fill: parent
        visible: root.sortOpen
        z: 40

        MouseArea {
            anchors.fill: parent
            onClicked: root.sortOpen = false
        }

        ShadowRect {
            id: sortCard
            // rechtsbündig unter dem Sortier-Knopf (sortButton und sortLayer teilen den Ursprung)
            x: Math.round(sortButton.x + sortButton.width - width)
            y: Math.round(sortButton.y + sortButton.height + 6)
            width: 190
            height: sortColumn.implicitHeight + 12
            color: Theme.menuBg
            radius: 14
            border.width: Theme.popoverBorderWidth
            border.color: Theme.outerBorders
            shadowColor: Theme.shadowColor
            shadowBlur: Theme.shadowPopoverBlur
            shadowOffsetY: Theme.shadowPopoverY
            padding: 6

            Column {
                id: sortColumn
                anchors.fill: parent
                Repeater {
                    model: root.sortingOptions
                    DropdownMenuItem {
                        required property var modelData
                        text: modelData.label
                        selected: root.sorting === modelData.id
                        onActivated: {
                            root.sorting = modelData.id;
                            root.sortOpen = false;
                            root.startSearch();
                        }
                    }
                }
            }
        }
    }

    // ───────── Raster ─────────
    Flickable {
        id: gridFlick
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Platz für die Fußleiste (Status/Nachladen), damit die Miniaturen nicht darunter liegen
        anchors.bottomMargin: 56
        clip: true
        contentHeight: Math.max(height, grid.implicitHeight + 32)
        boundsBehavior: Flickable.StopAtBounds

        // Größere Radschritte nur auf dieser Seite
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const max = Math.max(0, gridFlick.contentHeight - gridFlick.height);
                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                gridFlick.contentY = Math.max(0, Math.min(max, gridFlick.contentY - delta * 4));
            }
        }

        readonly property real sideMargin: 16
        readonly property real gap: 16
        readonly property real cellWidth: Math.floor((width - 2 * sideMargin - gap) / 2)
        readonly property real cellHeight: Math.round((cellWidth - 2) * 9 / 16)

        Grid {
            id: grid
            x: gridFlick.sideMargin
            y: 16
            width: parent.width - 2 * gridFlick.sideMargin
            columns: 2
            spacing: gridFlick.gap

            Repeater {
                model: root.results

                Rectangle {
                    id: cell
                    required property var modelData
                    readonly property bool busy: root.applying === modelData.id
                    width: gridFlick.cellWidth
                    height: gridFlick.cellHeight
                    radius: 12
                    color: Theme.alpha(Theme.windowFg, 0.06)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: cell.modelData.thumbs ? cell.modelData.thumbs.large : ""
                        sourceSize: Qt.size(Math.round(cell.width * 1.4), Math.round(cell.height * 1.4))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    // Hover-Hinweis
                    Rectangle {
                        anchors.fill: parent
                        visible: cellMouse.containsMouse && !cell.busy
                        color: "#73000000"
                        radius: 12
                        Text {
                            anchors.centerIn: parent
                            text: "Set wallpaper"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            font.weight: Theme.fontWeightBold
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: cell.busy
                        color: "#b3000000"
                        radius: 12
                        Text {
                            anchors.centerIn: parent
                            text: "Applying…"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.applying === ""
                        onClicked: root.applyResult(cell.modelData)
                    }
                }
            }
        }
    }

    // Status- und Nachladezeile unten
    Row {
        id: statusRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.error !== "" || root.loading
            text: root.loading ? "Searching…" : root.error
            color: Theme.alpha(Theme.windowFg, 0.7)
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeCaption
        }
        Button {
            visible: root.page > 0 && root.results.length > 0
            enabled: !root.loading && !root.loadingMore
            text: root.loadingMore ? "Loading…" : "Load More"
            onClicked: root.fetchPage()
        }
    }

    // Nur die (für Reparatur nicht benötigten) Kategorien im Preferences-Fenster
    Item {
        id: prefsOverlay
        anchors.fill: parent
        visible: root.prefsOpen
        z: 60

        Rectangle {
            anchors.fill: parent
            color: "#8c000000"
            MouseArea {
                anchors.fill: parent
                onClicked: root.prefsOpen = false
            }
        }

        ShadowRect {
            id: prefsCard
            anchors.centerIn: parent
            width: Math.min(root.width - 48, 520)
            height: prefsColumn.implicitHeight + 24
            color: Theme.menuBg
            radius: 16
            border.width: Theme.popoverBorderWidth
            border.color: Theme.outerBorders
            shadowColor: Theme.shadowColor
            shadowBlur: Theme.shadowPopoverBlur
            shadowOffsetY: Theme.shadowPopoverY
            padding: 0

            // Klicks im Fenster nicht nach außen durchreichen
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: prefsColumn
                x: 20
                y: 16
                width: parent.width - 40
                spacing: 6

                // Kopf
                Item {
                    width: parent.width
                    height: 28
                    Icon {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        name: "system-search-symbolic"
                        color: Theme.alpha(Theme.windowFg, 0.8)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Preferences"
                        color: Theme.windowFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightBold
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "window-close-symbolic"
                        flat: true
                        padding: 6
                        onClicked: root.prefsOpen = false
                    }
                }

                Item {
                    width: parent.width
                    height: 10
                }

                // Registerkarte: Kategorien
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.prefsTab === "categories"

                    Text {
                        text: "Wallpaper Categories"
                        color: Theme.windowFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        width: parent.width
                        text: "Select the types of wallpapers you want to see"
                        color: Theme.alpha(Theme.windowFg, 0.55)
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                    }

                    Repeater {
                        model: [
                            {
                                "key": "general",
                                "title": "General",
                                "subtitle": "General wallpapers"
                            },
                            {
                                "key": "anime",
                                "title": "Anime",
                                "subtitle": "Anime/Manga style"
                            },
                            {
                                "key": "people",
                                "title": "People",
                                "subtitle": "Wallpapers featuring people"
                            }
                        ]

                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: 0

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.alpha(Theme.windowFg, 0.08)
                            }
                            Item {
                                width: parent.width
                                height: 56

                                // Titel oben, Untertitel darunter (linksbündig, Block vertikal zentriert)
                                Column {
                                    anchors.left: parent.left
                                    anchors.right: toggle.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: modelData.title
                                        color: Theme.windowFg
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSizeBase
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.subtitle
                                        color: Theme.alpha(Theme.windowFg, 0.55)
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSizeCaption
                                    }
                                }

                                ToggleSwitch {
                                    id: toggle
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: modelData.key === "general" ? root.catGeneral : (modelData.key === "anime" ? root.catAnime : root.catPeople)
                                    onToggled: {
                                        if (modelData.key === "general")
                                            root.catGeneral = checked;
                                        else if (modelData.key === "anime")
                                            root.catAnime = checked;
                                        else
                                            root.catPeople = checked;
                                        root.startSearch();
                                    }
                                }
                            }
                        }
                    }
                }

                // Registerkarte: Inhaltsfilter
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.prefsTab === "safety"

                    Text {
                        text: "Content Safety"
                        color: Theme.windowFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        width: parent.width
                        text: "Choose which content ratings to include"
                        color: Theme.alpha(Theme.windowFg, 0.55)
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                    }

                    Repeater {
                        model: [
                            {
                                "key": "sfw",
                                "title": "Safe for Work",
                                "subtitle": "Family-friendly wallpapers"
                            },
                            {
                                "key": "sketchy",
                                "title": "Sketchy",
                                "subtitle": "Suggestive but not explicit"
                            }
                        ]

                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: 0

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.alpha(Theme.windowFg, 0.08)
                            }
                            Item {
                                width: parent.width
                                height: 56

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: toggle.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: modelData.title
                                        color: Theme.windowFg
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSizeBase
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.subtitle
                                        color: Theme.alpha(Theme.windowFg, 0.55)
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSizeCaption
                                    }
                                }

                                ToggleSwitch {
                                    id: toggle
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: modelData.key === "sfw" ? root.puritySfw : root.puritySketchy
                                    onToggled: {
                                        if (modelData.key === "sfw")
                                            root.puritySfw = checked;
                                        else
                                            root.puritySketchy = checked;
                                        root.startSearch();
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 8
                }

                // Untere Navigationsknöpfe
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Item {
                        width: 92
                        height: 52
                        readonly property bool active: root.prefsTab === "categories"
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: parent.active ? Theme.alpha(Theme.windowFg, 0.10) : "transparent"
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            name: "view-app-grid-symbolic"
                            color: parent.active ? Theme.windowFg : Theme.alpha(Theme.windowFg, 0.7)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: "Categories"
                            color: parent.active ? Theme.windowFg : Theme.alpha(Theme.windowFg, 0.7)
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeCaption
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.prefsTab = "categories"
                        }
                    }

                    Item {
                        width: 92
                        height: 52
                        readonly property bool active: root.prefsTab === "safety"
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: parent.active ? Theme.alpha(Theme.windowFg, 0.10) : "transparent"
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            name: "security-high-symbolic"
                            color: parent.active ? Theme.windowFg : Theme.alpha(Theme.windowFg, 0.7)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: "Content Safety"
                            color: parent.active ? Theme.windowFg : Theme.alpha(Theme.windowFg, 0.7)
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeCaption
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.prefsTab = "safety"
                        }
                    }
                }
            }
        }
    }

    // Zahnrad: Preferences öffnen
    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        z: 70
        icon: "emblem-system-symbolic"
        padding: 9
        onClicked: {
            root.prefsTab = "categories";
            root.prefsOpen = true;
        }
    }
}
