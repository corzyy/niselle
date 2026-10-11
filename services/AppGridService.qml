pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ordner und Seitenlayout des App-Grids. Gespeichert in Quickshell.statePath("appgrid.json"):
//   folderOrder  Ordner-IDs in Reihenfolge
//   folders      { id: { name, apps, categories, excluded } }
//   pages        Seiten mit Eintrags-IDs in Reihenfolge
// Änderungen wirken sofort und werden danach in die Datei geschrieben; Änderungen an der Datei von außen werden übernommen.
//
// Begriffe: Eintrag = App (ID mit .desktop) oder Ordner (Ordner-ID). Das Grid zeigt Ordner und Apps, die weder Favorit
// (Dash) noch in einem Ordner sind [appDisplay.js: _loadApps].
Singleton {
    id: root

    // folder-children in Reihenfolge
    property var folderOrder: []
    // { id: { name, apps: [], categories: [], excluded: [] } }
    property var folders: ({})
    // Gespeichertes Layout: Seiten mit Eintrags-IDs in Reihenfolge
    property var storedPages: []

    // Platzhalter-ID für ein fremdes Icon, das gerade über das Grid gezogen wird
    readonly property string placeholderId: "\u0000placeholder"

    // Ein Eintrag je ID: { id, kind: "app"|"folder", name, entry, apps: [Eintrag] }
    readonly property var model: root._buildModel()
    // Gespeicherte Seiten, gefiltert auf vorhandene Einträge; `unplaced`: Einträge ohne Platz, nach Name sortiert
    readonly property var layout: root._buildLayout()

    function item(id) {
        return root.model.byId[id] ?? null;
    }

    // ───────── Aufbau ─────────

    function _desktopId(entry) {
        return entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop";
    }

    function folderName(f, id) {
        return f ? (f.name || id) : "";
    }

    // Apps eines Ordners: apps-Liste in Reihenfolge, dann Apps mit passender Kategorie (nach Name) [appDisplay.js: FolderView._loadApps]
    function _folderMembers(f, appsById, sortedIds) {
        const out = [];
        const seen = {};
        const excluded = f.excluded ?? [];
        for (const id of f.apps ?? []) {
            if (appsById[id] && !seen[id] && excluded.indexOf(id) < 0) {
                seen[id] = true;
                out.push(id);
            }
        }
        const cats = f.categories ?? [];
        if (cats.length > 0) {
            for (const id of sortedIds) {
                if (seen[id] || excluded.indexOf(id) >= 0)
                    continue;
                const have = appsById[id].categories ?? [];
                if (cats.some(c => have.indexOf(c) >= 0)) {
                    seen[id] = true;
                    out.push(id);
                }
            }
        }
        return out;
    }

    function _buildModel() {
        const favorites = {};
        for (const id of AppsService.favoriteIds)
            favorites[id] = true;
        const appsById = {};
        const sortedIds = [];
        for (const e of AppsService.apps) {
            const id = root._desktopId(e);
            if (favorites[id] || appsById[id])
                continue;
            appsById[id] = e;
            sortedIds.push(id);
        }
        const byId = {};
        const inFolder = {};
        const list = [];
        for (const fid of root.folderOrder) {
            const f = root.folders[fid];
            if (!f)
                continue;
            const members = root._folderMembers(f, appsById, sortedIds);
            // Leere Ordner erscheinen nicht [appDisplay.js:1544-1548]
            if (members.length === 0)
                continue;
            for (const m of members)
                inFolder[m] = true;
            const it = {
                "id": fid,
                "kind": "folder",
                "name": root.folderName(f, fid),
                "entry": null,
                "apps": members.map(m => appsById[m]),
                "appIds": members
            };
            byId[fid] = it;
            list.push(it);
        }
        for (const id of sortedIds) {
            if (inFolder[id])
                continue;
            const it = {
                "id": id,
                "kind": "app",
                "name": appsById[id].name,
                "entry": appsById[id],
                "apps": [],
                "appIds": []
            };
            byId[id] = it;
            list.push(it);
        }
        return {
            "byId": byId,
            "list": list,
            "appsById": appsById
        };
    }

    function _buildLayout() {
        const byId = root.model.byId;
        const placed = {};
        const pages = [];
        for (const page of root.storedPages) {
            // Nacheinander prüfen: dieselbe ID kann auch innerhalb einer Seite doppelt stehen
            const ids = page.filter(id => {
                if (!byId[id] || placed[id])
                    return false;
                placed[id] = true;
                return true;
            });
            if (ids.length > 0)
                pages.push(ids);
        }
        const unplaced = root.model.list.filter(it => !placed[it.id]).sort((a, b) => a.name.localeCompare(b.name)).map(it => it.id);
        return {
            "pages": pages,
            "unplaced": unplaced
        };
    }

    // ───────── Änderungen ─────────

    function savePages(pages) {
        const clean = pages.map(p => p.filter(id => id !== root.placeholderId)).filter(p => p.length > 0);
        root.storedPages = clean;
        root._save();
    }

    function _newFolderId() {
        const hex = n => Math.floor(Math.random() * Math.pow(16, n)).toString(16).padStart(n, "0");
        return hex(8) + "-" + hex(4) + "-4" + hex(3) + "-a" + hex(3) + "-" + hex(12);
    }

    // Neuen Ordner aus zwei Apps anlegen; `pages` ist das Layout danach (der Ordner steht an Stelle von `at`)
    function createFolder(appA, appB, name) {
        const id = root._newFolderId();
        const f = {
            "name": name || "Unbenannter Ordner",
            "apps": [appA, appB],
            "categories": [],
            "excluded": []
        };
        const folders = Object.assign({}, root.folders);
        folders[id] = f;
        root.folders = folders;
        root.folderOrder = root.folderOrder.concat([id]);
        root._save();
        return id;
    }

    function addAppToFolder(folderId, appId) {
        const f = root.folders[folderId];
        if (!f || f.apps.indexOf(appId) >= 0)
            return;
        root._setFolder(folderId, {
            "apps": f.apps.concat([appId]),
            "excluded": f.excluded.filter(i => i !== appId)
        });
    }

    // App aus dem Ordner nehmen; der letzte entfernt den Ordner [appDisplay.js: FolderView.removeApp]
    function removeAppFromFolder(folderId, appId) {
        const f = root.folders[folderId];
        if (!f)
            return;
        const apps = f.apps.filter(i => i !== appId);
        if (apps.length === 0 && f.categories.length === 0) {
            root.deleteFolder(folderId);
            return;
        }
        const patch = {
            "apps": apps
        };
        // Kategorie-Ordner führen entfernte Apps zusätzlich als ausgeschlossen
        if (f.categories.length > 0 && f.excluded.indexOf(appId) < 0)
            patch.excluded = f.excluded.concat([appId]);
        root._setFolder(folderId, patch);
    }

    function setFolderApps(folderId, ids) {
        root._setFolder(folderId, {
            "apps": ids
        });
    }

    function renameFolder(folderId, name) {
        const f = root.folders[folderId];
        const trimmed = name.trim();
        if (!f || trimmed === "" || trimmed === root.folderName(f, folderId))
            return;
        root._setFolder(folderId, {
            "name": trimmed
        });
    }

    function deleteFolder(folderId) {
        const folders = Object.assign({}, root.folders);
        delete folders[folderId];
        root.folders = folders;
        root.folderOrder = root.folderOrder.filter(i => i !== folderId);
        root._save();
    }

    function _setFolder(folderId, patch) {
        const f = Object.assign({}, root.folders[folderId], patch);
        const folders = Object.assign({}, root.folders);
        folders[folderId] = f;
        root.folders = folders;
        root._save();
    }

    // ───────── Datei ─────────

    function _save() {
        store.folderOrder = root.folderOrder;
        store.folders = root.folders;
        store.pages = root.storedPages;
    }

    FileView {
        path: Quickshell.statePath("appgrid.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.folderOrder = store.folderOrder ?? [];
            root.folders = store.folders ?? ({});
            root.storedPages = store.pages ?? [];
        }
        onLoadFailed: error => writeAdapter()

        adapter: JsonAdapter {
            id: store
            property var folderOrder: []
            property var folders: ({})
            property var pages: []
        }
    }
}
