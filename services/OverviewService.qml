pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property bool shown: false
    property real progress: 0
    property bool appsShown: false
    property real appsProgress: 0
    property real searchProgress: 0
    readonly property bool searchActive: SearchService.active
    property string openFolderId: ""

    property bool windowDragActive: false
    property string windowDragScreen: ""
    property point windowDragPoint: Qt.point(0, 0)
    property size windowDragSize: Qt.size(0, 0)
    property string windowDragIcon: ""
    property string windowDragTitle: ""

    signal appDroppedInGrid(string appId, real x, real y)

    property rect activeThumbnailRect: Qt.rect(0, 0, 0, 0)
    property point appsOrigin: Qt.point(0, 0)

    property var _restoreWorkspaces: []
    property int _openWorkspaceId: -1

    property bool captureArmed: false
    signal refreshCaptures(bool activeOnly)
    Timer {
        id: armTimer
        interval: Theme.gameMode ? 0 : Theme.durationOverview
        onTriggered: {
            if (!root.shown)
                return;
            root.captureArmed = true;
            root.refreshCaptures(false);
        }
    }
    onVisibleChanged: {
        if (!root.visible) {
            armTimer.stop();
            root.captureArmed = false;
            root._restoreWorkspaceAnimations();
        }
    }

    property bool scanoutSensitive: true
    Process {
        running: true
        command: ["sh", "-c", "for o in render:direct_scanout general:allow_tearing misc:vrr; do hyprctl getoption $o -j; echo; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                let sensitive = false;
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    try {
                        const o = JSON.parse(line);
                        if ((o.int ?? 0) !== 0 || o.bool === true)
                            sensitive = true;
                    } catch (e) {
                        sensitive = true;
                    }
                }
                root.scanoutSensitive = sensitive;
            }
        }
    }

    readonly property var _workspaceLeaves: ["workspaces", "workspacesIn", "workspacesOut"]
    readonly property var _savedAnimations: animStore.saved
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/niselle/workspace-animations.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            if (!root.shown)
                root._restoreWorkspaceAnimations();
        }
        adapter: JsonAdapter {
            id: animStore
            property var saved: []
        }
    }
    Process {
        id: animQuery
        command: ["hyprctl", "animations", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root._disableWorkspaceAnimations(text)
        }
    }
    function _disableWorkspaceAnimations(text) {
        if (!root.shown || (root._savedAnimations && root._savedAnimations.length > 0))
            return;
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return;
        }
        const list = (Array.isArray(data) && Array.isArray(data[0])) ? data[0] : [];
        const saved = list.filter(a => root._workspaceLeaves.indexOf(a.name) >= 0 && a.enabled);
        if (saved.length === 0)
            return;
        animStore.saved = saved;
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "eval", saved.map(a => 'hl.animation({ leaf = "' + a.name + '", enabled = false })').join("; ")]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", saved.map(a => "keyword animation " + a.name + ",0").join(" ; ")]);
    }
    function _restoreWorkspaceAnimations() {
        const saved = root._savedAnimations;
        if (!saved || saved.length === 0)
            return;
        animStore.saved = [];
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "eval", saved.map(a => 'hl.animation({ leaf = "' + a.name + '", enabled = true, speed = ' + a.speed + ', bezier = "' + a.bezier + '"' + (a.style ? ', style = "' + a.style + '"' : "") + " })").join("; ")]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", saved.map(a => "keyword animation " + a.name + ",1," + a.speed + "," + a.bezier + (a.style ? "," + a.style : "")).join(" ; ")]);
    }

    function _primaryWorkspaceId() {
        const mon = Hyprland.monitors.values.find(m => m.name === Theme.primaryScreenName);
        return mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
    }

    Timer {
        id: restoreTimer
        interval: 60
        onTriggered: {
            if (root.shown)
                return;
            for (const w of root._restoreWorkspaces) {
                if (root._primaryWorkspaceId() === w.id)
                    continue;
                const classic = "workspace " + w.id;
                const lua = 'hl.dsp.focus({ workspace = ' + w.id + ' })';
                Hyprland.dispatch(Hyprland.usingLua ? lua : classic);
            }
            root._restoreWorkspaces = [];
        }
    }

    function _lastWindowOf(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (!ws)
            return "";
        const wins = ws.toplevels.values;
        const last = ws.lastIpcObject?.lastwindow ?? "";
        const lastClean = last.replace(/^0x/, "");
        if (last !== "" && last !== "0x0" && wins.some(t => t.address.replace(/^0x/, "") === lastClean))
            return last;
        return wins.length > 0 ? wins[0].address : "";
    }

    property point folderOrigin: Qt.point(-1, -1)
    function openFolder(id, origin) {
        if (origin)
            root.folderOrigin = origin;
        root.openFolderId = id;
    }
    function closeFolder() {
        root.openFolderId = "";
    }
    readonly property bool visible: shown || progress > 0 || animating
    readonly property bool animating: anim.running

    readonly property var primaryScreen: (Theme.primaryScreenName === "" && !(DisplayService.loaded && SettingsService.loaded)) ? null : Quickshell.screens.find(s => s.name === Theme.primaryScreenName) ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    function isPrimary(screen) {
        return !!screen && !!root.primaryScreen && screen.name === root.primaryScreen.name;
    }

    property double activatedAt: 0
    property double changedAt: 0

    function show(withApps) {
        if (root.shown)
            return;
        root.activatedAt = root.changedAt = Date.now();
        root.shown = true;
        Hyprland.refreshToplevels();
        root._openWorkspaceId = root._primaryWorkspaceId();
        SearchService.reset();
        if (withApps === true) {
            root.appsProgress = 0;
            root.appsShown = true;
        }
        root._animate(1);
        root.captureArmed = false;
        root.refreshCaptures(true);
        armTimer.restart();
        if (!Theme.gameMode && (!root._savedAnimations || root._savedAnimations.length === 0))
            animQuery.running = true;
    }
    function openSearch(text) {
        if (!root.shown)
            root.show();
        else if (root.appsShown)
            root.appsShown = false;
        SearchService.text = text;
    }
    function hide() {
        if (!root.shown)
            return;
        const pending = WorkspaceService.pendingFor(root.primaryScreen);
        const current = pending > 0 ? pending : root._primaryWorkspaceId();
        root._restoreWorkspaces = (current > 0 && current !== root._openWorkspaceId)
            ? [{
                    monitor: Theme.primaryScreenName,
                    id: current
                }] : [];
        if (root._restoreWorkspaces.length > 0 && Date.now() - WorkspaceService.lastFocusRequest > 500) {
            const address = root._lastWindowOf(current);
            if (address !== "")
                WorkspaceService.focusAddress(address);
        }
        root.shown = false;
        root.appsShown = false;
        root.openFolderId = "";
        SearchService.reset();
        root.changedAt = Date.now();
        root._animate(0);
        restoreTimer.restart();
    }
    function toggle() {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function toggleApps() {
        if (!root.shown) {
            root.show(true);
            return;
        }
        SearchService.reset();
        root.appsShown = !root.appsShown;
    }

    function dismiss() {
        if (SearchService.active)
            SearchService.reset();
        else if (root.openFolderId !== "")
            root.closeFolder();
        else if (root.appsShown)
            root.appsShown = false;
        else
            root.hide();
    }

    onAppsShownChanged: {
        appsAnim.stop();
        appsAnim.to = root.appsShown ? 1 : 0;
        appsAnim.start();
    }
    onSearchActiveChanged: {
        searchAnim.stop();
        searchAnim.to = root.searchActive ? 1 : 0;
        searchAnim.start();
    }

    function toggleByCornerOrButton() {
        if (root.animating)
            return;
        if (root.activatedAt > 0 && Date.now() - root.activatedAt < Theme.overviewActivationTimeout)
            return;
        root.toggle();
    }

    function toggleByShortcut() {
        if (Date.now() - root.changedAt < Theme.overviewShortcutDebounce)
            return;
        root.toggle();
    }

    function _animate(to) {
        anim.stop();
        anim.from = root.progress;
        anim.to = to;
        anim.elapsed = 0;
        anim.start();
    }

    FrameAnimation {
        id: anim

        readonly property real maxStep: 0.022
        property real from: 0
        property real to: 0
        property real elapsed: 0

        onTriggered: {
            const duration = Theme.gameMode ? 0 : Theme.durationOverview / 1000;
            elapsed += Math.min(frameTime, maxStep);
            const t = duration > 0 ? Math.min(1, elapsed / duration) : 1;
            root.progress = from + (to - from) * (1 - Math.pow(1 - t, 3));
            if (t >= 1)
                stop();
        }
    }

    NumberAnimation {
        id: appsAnim
        target: root
        property: "appsProgress"
        duration: Theme.gameMode ? 0 : Theme.durationAppGridReveal
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: searchAnim
        target: root
        property: "searchProgress"
        duration: Theme.gameMode ? 0 : Theme.motionMedium
        easing.type: Theme.easeEmphasized
    }

    GlobalShortcut {
        appid: "niselle"
        name: "overview"
        description: "Übersicht ein-/ausblenden"
        onPressed: root.toggleByShortcut()
        onReleased: root.toggleByShortcut()
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggleByShortcut();
        }
        function open(): void {
            root.show();
        }
        function apps(): void {
            root.toggleApps();
        }
        function close(): void {
            root.hide();
        }
        function search(text: string): void {
            root.openSearch(text);
        }
    }

    Component.onCompleted: {
        if (Quickshell.env("NISELLE_OVERVIEW") === "1") {
            root.shown = true;
            root.progress = 1;
        }
        if (Quickshell.env("NISELLE_APPS") === "1") {
            root.shown = true;
            root.progress = 1;
            root.appsProgress = 1;
            root.appsShown = true;
        }
    }
}
