pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "fuzzy.js" as Fuzzy

Singleton {
    id: root

    readonly property bool available: apps.length > 0


    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    function byId(id) {
        if (!id)
            return null;
        return DesktopEntries.byId(id.replace(/\.desktop$/, "")) ?? DesktopEntries.byId(id) ?? null;
    }

    signal launched(var entry)

    function launch(entry) {
        if (!entry)
            return;
        entry.execute();
        root.launched(entry);
    }
    function launchAction(action) {
        if (action)
            action.execute();
    }

    function activate(entry) {
        const running = root.runningFor(entry);
        if (running && running.windows.length > 0)
            WorkspaceService.focusWindow(running.windows[0]);
        else
            root.launch(entry);
    }

    function openNewWindow(entry) {
        if (!entry)
            return;
        for (const action of entry.actions) {
            if (action.id === "new-window") {
                root.launchAction(action);
                root.launched(entry);
                return;
            }
        }
        root.launch(entry);
    }

    function quit(entry) {
        const running = root.runningFor(entry);
        if (running)
            running.windows.forEach(w => WorkspaceService.closeWindow(w));
    }


    readonly property var defaultFavorites: ["firefox.desktop", "chromium.desktop", "thunar.desktop", "pcmanfm.desktop", "dolphin.desktop", "kitty.desktop", "foot.desktop", "alacritty.desktop"]

    readonly property var favoriteIds: store.ids ?? []
    readonly property var favorites: apps.length >= 0 ? favoriteIds.map(id => root.byId(id)).filter(e => e) : []

    function isFavorite(entry) {
        return entry ? favoriteIds.indexOf(root._desktopId(entry)) >= 0 : false;
    }
    function addFavorite(entry, index) {
        const id = root._desktopId(entry);
        if (!entry || favoriteIds.indexOf(id) >= 0)
            return;
        const list = favoriteIds.slice();
        list.splice(index === undefined ? list.length : index, 0, id);
        root._setFavorites(list);
    }
    function removeFavorite(entry) {
        root._setFavorites(favoriteIds.filter(id => id !== root._desktopId(entry)));
    }
    function moveFavorite(entry, index) {
        const id = root._desktopId(entry);
        const list = favoriteIds.filter(i => i !== id);
        list.splice(Math.max(0, Math.min(list.length, index)), 0, id);
        root._setFavorites(list);
    }
    function toggleFavorite(entry) {
        if (isFavorite(entry))
            removeFavorite(entry);
        else
            addFavorite(entry);
    }

    function _desktopId(entry) {
        return entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop";
    }
    function _setFavorites(list) {
        store.ids = list;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/niselle/favorites.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            store.ids = root.defaultFavorites.filter(id => root.byId(id));
            writeAdapter();
        }
        adapter: JsonAdapter {
            id: store
            property var ids: []
        }
    }


    function _norm(s) {
        const text = s && typeof s !== "string" ? Array.from(s).join(" ") : (s || "");
        return Fuzzy.norm(text);
    }

    function makeIndex(entries) {
        return entries.map(e => ({
                    entry: e,
                    name: _norm(e.name),
                    generic: _norm(e.genericName),
                    keywords: _norm(e.keywords),
                    comment: _norm(e.comment),
                    id: _norm(e.id)
                }));
    }

    readonly property var _index: makeIndex(apps)

    function search(query, limit) {
        return root.searchIndex(root._index, query, limit);
    }

    function searchIndex(index, query, limit) {
        const words = root._norm(query).split(/\s+/).filter(w => w);
        if (words.length === 0)
            return [];
        const scored = [];
        for (const item of index) {
            let total = 0;
            for (const w of words) {
                const s = root._score(item, w);
                if (s === 0) {
                    total = 0;
                    break;
                }
                total += s;
            }
            if (total > 0)
                scored.push({
                    entry: item.entry,
                    score: total
                });
        }
        scored.sort((a, b) => (b.score - a.score) || a.entry.name.localeCompare(b.entry.name));
        const out = scored.map(s => s.entry);
        return limit ? out.slice(0, limit) : out;
    }

    function _score(item, w) {
        if (item.name.startsWith(w))
            return 1000;
        if (item.name.indexOf(" " + w) >= 0 || item.name.indexOf("-" + w) >= 0)
            return 800;
        if (item.name.indexOf(w) >= 0)
            return 600;
        if (item.generic.startsWith(w) || item.keywords.indexOf(w) >= 0)
            return 400;
        if (item.generic.indexOf(w) >= 0)
            return 300;
        if (item.id.indexOf(w) >= 0)
            return 200;
        if (item.comment.indexOf(w) >= 0)
            return 100;
        return Math.max(Fuzzy.fuzzyScore(w, item.name), Fuzzy.fuzzyScore(w, item.generic) * 0.8);
    }


    readonly property var runningApps: {
        const byClass = {};
        const list = [];
        for (const t of Hyprland.toplevels.values) {
            const cls = t.lastIpcObject.class;
            if (!cls)
                continue;
            let r = byClass[cls.toLowerCase()];
            if (!r) {
                r = {
                    appId: cls,
                    entry: root._entryForClass(cls),
                    windows: []
                };
                byClass[cls.toLowerCase()] = r;
                list.push(r);
            }
            r.windows.push(t);
        }
        return list;
    }

    function runningFor(entry) {
        return entry ? runningApps.find(r => r.entry && r.entry.id === entry.id) ?? null : null;
    }
    function isRunning(entry) {
        return runningFor(entry) !== null;
    }
    function windowCount(entry) {
        const r = runningFor(entry);
        return r ? r.windows.length : 0;
    }

    function entryForWindow(toplevel) {
        const cls = toplevel?.lastIpcObject?.class;
        return cls ? root._entryForClass(cls) : null;
    }

    function entryForClass(cls) {
        return cls ? root._entryForClass(cls) : null;
    }

    function _entryForClass(cls) {
        const c = cls.toLowerCase();
        return root.apps.find(e => e.id.toLowerCase() === c || e.startupClass.toLowerCase() === c) ?? DesktopEntries.heuristicLookup(cls) ?? null;
    }
}
