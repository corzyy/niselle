import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

FloatingWindow {
    id: win

    readonly property var groups: SettingsPanelsService.groups
    readonly property var subpageTitles: SettingsPanelsService.subpageTitles
    readonly property var pageFiles: SettingsPanelsService.pageFiles

    readonly property string panel: SettingsWindowService.panel
    readonly property string section: panel.split("/")[0]
    readonly property bool isSubpage: panel.indexOf("/") >= 0
    readonly property string pageTitle: win.titleFor(win.panel)

    function pageFileFor(p) {
        if (p.startsWith("displays/monitor/"))
            return "MonitorSettingsPage";
        return win.pageFiles[p];
    }
    function parentPanelFor(p) {
        if (p.startsWith("displays/monitor/"))
            return "displays";
        if (p === "system/defaultapps")
            return "system";
        const i = p.lastIndexOf("/");
        return i >= 0 ? p.slice(0, i) : p;
    }
    function titleFor(p) {
        if (p.startsWith("displays/monitor/"))
            return p.slice("displays/monitor/".length);
        if (subpageTitles[p])
            return subpageTitles[p];
        const sec = p.split("/")[0];
        for (const g of groups)
            for (const i of g)
                if (i.id === sec)
                    return i.title;
        return "Settings";
    }

    readonly property var pageItem: page.item
    readonly property bool applyBar: !!(pageItem && pageItem.showingApplyBar === true)

    property bool searching: false
    property string query: ""

    readonly property var targetScreen: win.screen ? win.screen : OverviewService.primaryScreen
    readonly property int screenWidth: win.targetScreen ? win.targetScreen.width : 1280
    readonly property int screenHeight: win.targetScreen ? win.targetScreen.height : 800

    readonly property int preferredWidth: Math.min(Math.max(Math.round(screenWidth * 0.8), 640), 1100)
    readonly property int preferredHeight: Math.min(Math.max(Math.round(screenHeight * 0.8), 480), 820)

    readonly property int compactBreakpoint: 720
    readonly property bool compact: win.width > 0 && win.width < win.compactBreakpoint
    property bool sidebarOpen: false
    readonly property real sidebarWidth: win.compact ? Math.min(280, win.width * 0.85) : Math.max(240, Math.min(280, win.width * 0.3))

    title: "Settings"
    implicitWidth: win.preferredWidth
    implicitHeight: win.preferredHeight
    minimumSize: Qt.size(Math.min(640, win.screenWidth), Math.min(480, win.screenHeight))
    maximumSize: Qt.size(win.screenWidth, win.screenHeight)
    color: "transparent"
    visible: SettingsWindowService.open

    onVisibleChanged: {
        if (!visible) {
            SettingsWindowService.hide();
        } else {
            AboutService.reload();
            win.sidebarOpen = false;
        }
    }

    function go(p) {
        SettingsWindowService.panel = p;
        win.sidebarOpen = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: win.maximized ? 0 : Theme.radiusWindow
        color: Theme.windowBg
        clip: true

        Keys.onEscapePressed: {
            if (win.sidebarOpen)
                win.sidebarOpen = false;
            else if (win.searching) {
                win.searching = false;
                win.query = "";
            }
        }

        Item {
            id: content
            x: win.compact ? 0 : win.sidebarWidth + 1
            width: parent.width - x
            height: parent.height

            Rectangle {
                id: header
                width: parent.width
                height: 60
                color: Theme.windowBg

                IconButton {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (win.compact || win.isSubpage) && !win.applyBar
                    icon: win.isSubpage ? "go-previous-symbolic" : "open-menu-symbolic"
                    flat: true
                    bg: Theme.windowBg
                    padding: 8
                    onClicked: {
                        if (win.isSubpage)
                            win.go(win.parentPanelFor(win.panel));
                        else
                            win.sidebarOpen = !win.sidebarOpen;
                    }
                }
                Button {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.applyBar
                    text: "Cancel"
                    onClicked: {
                        if (win.pageItem && win.pageItem.cancelConfiguration)
                            win.pageItem.cancelConfiguration();
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 48
                    anchors.rightMargin: 48
                    text: win.applyBar ? "Apply Changes?" : win.pageTitle
                    onTextChanged: {
                        if (!Theme.gameMode)
                            titleIn.restart();
                    }
                    NumberAnimation on opacity {
                        id: titleIn
                        running: false
                        from: 0
                        to: 1
                        duration: Theme.durationOverview
                        easing.type: Theme.easeOutCubic
                    }
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase * 1.2
                    font.weight: Theme.fontWeightBold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                Button {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.applyBar
                    text: "Apply"
                    primary: true
                    onClicked: {
                        if (win.pageItem && win.pageItem.applyConfiguration)
                            win.pageItem.applyConfiguration();
                    }
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !win.applyBar
                    icon: "window-close-symbolic"
                    padding: 4
                    bg: Theme.windowBg
                    onClicked: SettingsWindowService.hide()
                }
            }

            Loader {
                id: page
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                source: win.pageFileFor(win.panel) ? Qt.resolvedUrl("pages/" + win.pageFileFor(win.panel) + ".qml") : ""
                active: win.pageFileFor(win.panel) !== undefined

                transform: Translate {
                    id: pageShift
                }
                onLoaded: {
                    if (Theme.gameMode)
                        return;
                    pageIn.stop();
                    pageIn.start();
                }
                ParallelAnimation {
                    id: pageIn
                    NumberAnimation {
                        target: page
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.durationOverview
                        easing.type: Theme.easeOutCubic
                    }
                    NumberAnimation {
                        target: pageShift
                        property: "x"
                        from: win.isSubpage ? 24 : 0
                        to: 0
                        duration: Theme.durationOverview
                        easing.type: Theme.easeOutCubic
                    }
                    NumberAnimation {
                        target: pageShift
                        property: "y"
                        from: win.isSubpage ? 0 : 10
                        to: 0
                        duration: Theme.durationOverview
                        easing.type: Theme.easeOutCubic
                    }
                }
            }

            Connections {
                target: page.item
                ignoreUnknownSignals: true
                function onNavigate(p) {
                    win.go(p);
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.compact && win.sidebarOpen ? 1 : 0
            color: Theme.alpha("#000000", 0.35)
            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.durationWindowOverlay
                    easing.type: Theme.easeOutQuad
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: win.sidebarOpen = false
            }
        }

        Rectangle {
            id: sidebar
            width: win.sidebarWidth
            height: parent.height
            color: Theme.sidebarBg
            z: win.compact ? 2 : 0
            x: win.compact ? (win.sidebarOpen ? 0 : -width) : 0
            Behavior on x {
                enabled: win.compact && !Theme.gameMode
                NumberAnimation {
                    duration: Theme.durationWindowOverlay
                    easing.type: Theme.easeOutQuad
                }
            }

            Item {
                id: sidebarHeader
                width: parent.width
                height: 60

                IconButton {
                    id: searchButton
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "system-search-symbolic"
                    flat: true
                    bg: Theme.sidebarBg
                    padding: 8
                    checkable: true
                    checked: win.searching
                    onClicked: {
                        win.searching = !win.searching;
                        if (win.searching)
                            searchEntry.forceFocus();
                        else
                            win.query = "";
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !win.searching
                    text: "Settings"
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }
                Entry {
                    id: searchEntry
                    visible: win.searching
                    anchors.left: searchButton.right
                    anchors.right: menuButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 4
                    paddingV: 5
                    placeholderText: "Search"
                    onTextChanged: win.query = text
                }
                IconButton {
                    id: menuButton
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "open-menu-symbolic"
                    flat: true
                    bg: Theme.sidebarBg
                    padding: 8
                    onClicked: menu.toggle()
                }

                PopupMenu {
                    id: menu

                    anchor.item: menuButton
                    anchor.rect.x: menuButton.width + margin - 1
                    anchor.rect.y: menuButton.height + Theme.popoverRise - margin - 1
                    anchor.rect.width: 1
                    anchor.rect.height: 1
                    anchor.edges: Edges.Bottom | Edges.Right
                    anchor.gravity: Edges.Bottom | Edges.Left
                    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip

                    PopupMenuItem {
                        text: "Help"
                        icon: "help-about-symbolic"
                        onActivated: Quickshell.execDetached(["xdg-open", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"])
                    }
                }
            }

            Rectangle {
                visible: !win.compact
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.alpha(Theme.windowFg, Theme.dark ? 0.07 : 0.1)
            }

            Flickable {
                anchors.top: sidebarHeader.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                contentHeight: groupsColumn.implicitHeight + 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: groupsColumn
                    width: parent.width

                    Repeater {
                        model: win.groups

                        Column {
                            id: group

                            required property var modelData
                            required property int index
                            readonly property var shown: modelData.filter(i => win.query === "" || i.title.toLowerCase().includes(win.query.toLowerCase()))
                            width: groupsColumn.width
                            visible: shown.length > 0

                            Item {
                                visible: group.index > 0
                                width: 1
                                height: 8
                            }

                            Repeater {
                                model: group.shown

                                SidebarRow {
                                    required property var modelData
                                    width: group.width
                                    title: modelData.title
                                    icon: modelData.icon
                                    selected: win.section === modelData.id
                                    onActivated: win.go(modelData.id)
                                }
                            }
                            Item {
                                width: 1
                                height: 5
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: win.maximized ? 0 : Theme.radiusWindow
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.windowFg, 0.12)
        }
    }
}
